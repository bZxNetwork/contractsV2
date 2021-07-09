pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/Upgradeable.sol";
import "./GovToken.sol";
import "./MintCoordinator_BSC.sol";
import "./interfaces/IMasterChef.sol";


contract MasterChef_BSC is Upgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    // The GOV TOKEN!
    GovToken public GOV;
    // Dev address.
    address public devaddr;
    // Block number when bonus GOV period ends.
    uint256 public bonusEndBlock;
    // GOV tokens created per block.
    uint256 public GOVPerBlock;
    // Bonus muliplier for early GOV makers.
    uint256 public constant BONUS_MULTIPLIER = 10;
    // unused
    address public migrator;
    // Info of each pool.
    IMasterChef.PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => IMasterChef.UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when GOV mining starts.
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    uint256 internal constant GOV_POOL_ID = 7;
    event AddExternalReward(
        address indexed sender,
        uint256 indexed pid,
        uint256 amount
    );

    MintCoordinator public constant coordinator = MintCoordinator(0x68d57B33Fe3B691Ef96dFAf19EC8FA794899f2ac);

    mapping(IERC20 => bool) public poolExists;

    modifier nonDuplicated(IERC20 _lpToken) {
        require(!poolExists[_lpToken], "pool exists");
        _;
    }

    // total deposits in a pool
    mapping(uint256 => uint256) public balanceOf;

    // pool rewards locked for future claim
    mapping(uint256 => bool) public isLocked;

    // total locked rewards for a user
    mapping(address => uint256) public lockedRewards;

    bool public notPaused;

    modifier checkNoPause() {
        require(notPaused, "paused");
    _;
    }

    event AddAltReward(
        address indexed sender,
        uint256 indexed pid,
        uint256 amount
    );
    mapping(address => uint256) public altRewardsDebt;      // user => amount
    mapping(uint256 => uint256) public altRewardsPerShare;  // pid => amount

    function initialize(
        GovToken _GOV,
        address _devaddr,
        uint256 _GOVPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public onlyOwner {
        require(address(GOV) == address(0), "unauthorized");
        GOV = _GOV;
        devaddr = _devaddr;
        GOVPerBlock = _GOVPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate)
        public
        onlyOwner
        nonDuplicated(_lpToken)
    {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExists[_lpToken] = true;
        poolInfo.push(
            IMasterChef.PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accGOVPerShare: 0
            })
        );
    }

    // Update the given pool's GOV allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate)
        public
        onlyOwner
    {
        if (_withUpdate) {
            massUpdatePools();
        }

        IMasterChef.PoolInfo storage pool = poolInfo[_pid];
        require(address(pool.lpToken) != address(0) && poolExists[pool.lpToken], "pool not exists");
        totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(
            _allocPoint
        );
        pool.allocPoint = _allocPoint;

        if (block.number < pool.lastRewardBlock) {
            pool.lastRewardBlock = startBlock;
        }
    }

    function transferTokenOwnership(address newOwner)
        public
        onlyOwner
    {
        GOV.transferOwnership(newOwner);
    }

    function setStartBlock(uint256 _startBlock)
        public
        onlyOwner
    {
        startBlock = _startBlock;
    }

    function setLocked(uint256 _pid, bool _toggle)
        public
        onlyOwner
    {
        isLocked[_pid] = _toggle;
    }

    function setGOVPerBlock(uint256 _GOVPerBlock)
        public
        onlyOwner
    {
        massUpdatePools();
        GOVPerBlock = _GOVPerBlock;
    }

    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return getMultiplierPrecise(_from, _to).div(1e18);
    }

    function getMultiplierNow()
        public
        view
        returns (uint256)
    {
        return getMultiplierPrecise(block.number - 1, block.number);
    }

    function getMultiplierPrecise(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _getDecliningMultipler(_from, _to, startBlock);
    }

    function _getDecliningMultipler(uint256 _from, uint256 _to, uint256 _bonusStartBlock)
        internal
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(1e18);
        /*
        // _periodBlocks = 864000 = 60 * 60 * 24 * 30 / 3 = blocks_in_30_days
        uint256 _bonusEndBlock = _bonusStartBlock + 864000;

        // multiplier = 7.64e18 = BONUS_MULTIPLIER * 191 / 250 * 10^18
        // declinePerBlock = 7685185185185 = (7.64e18 - 1e18) / _periodBlocks

        uint256 _startMultipler;
        uint256 _endMultipler;
        uint256 _avgMultiplier;

        if (_to <= _bonusEndBlock) {
            _startMultipler = SafeMath.sub(7.64e18,
                _from.sub(_bonusStartBlock)
                    .mul(7685185185185)
            );

            _endMultipler = SafeMath.sub(7.64e18,
                _to.sub(_bonusStartBlock)
                    .mul(7685185185185)
            );

            _avgMultiplier = (_startMultipler + _endMultipler) / 2;

            return _to.sub(_from).mul(_avgMultiplier);
        } else if (_from >= _bonusEndBlock) {
            return _to.sub(_from).mul(1e18);
        } else {

            _startMultipler = SafeMath.sub(7.64e18,
                _from.sub(_bonusStartBlock)
                    .mul(7685185185185)
            );

            _endMultipler = 1e18;

            _avgMultiplier = (_startMultipler + _endMultipler) / 2;

            return _bonusEndBlock.sub(_from).mul(_avgMultiplier).add(
                    _to.sub(_bonusEndBlock).mul(1e18)
                );
        }*/
    }
    
    function _pendingGOV(uint256 _pid, address _user)
        internal
        view
        returns (uint256)
    {
        IMasterChef.PoolInfo storage pool = poolInfo[_pid];
        IMasterChef.UserInfo storage user = userInfo[_pid][_user];
        uint256 accGOVPerShare = pool.accGOVPerShare.mul(1e18);
        uint256 lpSupply = balanceOf[_pid];
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplierPrecise(pool.lastRewardBlock, block.number);
            uint256 GOVReward =
                multiplier.mul(GOVPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accGOVPerShare = accGOVPerShare.add(
                GOVReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accGOVPerShare).div(1e30).sub(user.rewardDebt);
    }

    function _pendingAltRewards(address _user)
        internal
        view
        returns (uint256)
    {
        return userInfo[GOV_POOL_ID][_user].amount
            .mul(altRewardsPerShare[GOV_POOL_ID])
            .div(1e12)
            .sub(altRewardsDebt[_user]);
    }

    // View function to see pending GOVs on frontend.
    function pendingGOV(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        return _pendingGOV(_pid, _user);
    }

    // View function to see pending alt rewards on frontend.
    function pendingAltRewards(address _user)
        external
        view
        returns (uint256)
    {
        return _pendingAltRewards(_user);
    }

    function togglePause(bool _isPaused) external onlyOwner {
        notPaused = !_isPaused;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public checkNoPause {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function massMigrateToBalanceOf() public onlyOwner {
        massUpdatePools();
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            balanceOf[pid] = poolInfo[pid].lpToken.balanceOf(address(this));
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public checkNoPause {
        IMasterChef.PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = balanceOf[_pid];
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplierPrecise(pool.lastRewardBlock, block.number);
        uint256 GOVReward =
            multiplier.mul(GOVPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        coordinator.mint(devaddr, GOVReward.div(1e19));
        coordinator.mint(address(this), GOVReward.div(1e18));
        pool.accGOVPerShare = pool.accGOVPerShare.add(
            GOVReward.div(1e6).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Anyone can contribute GOV to a given pool
    function addExternalReward(uint256 _amount) public checkNoPause {
        IMasterChef.PoolInfo storage pool = poolInfo[GOV_POOL_ID];
        require(block.number > pool.lastRewardBlock, "rewards not started");

        uint256 lpSupply = balanceOf[GOV_POOL_ID];
        require(lpSupply != 0, "no deposits");

        updatePool(GOV_POOL_ID);

        GOV.transferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        pool.accGOVPerShare = pool.accGOVPerShare.add(
            _amount.mul(1e12).div(lpSupply)
        );

        emit AddExternalReward(msg.sender, GOV_POOL_ID, _amount);
    }

    // Anyone can contribute native token rewards to GOV pool stakers
    function addAltReward() public payable checkNoPause {
        IMasterChef.PoolInfo storage pool = poolInfo[GOV_POOL_ID];
        require(block.number > pool.lastRewardBlock, "rewards not started");

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        require(lpSupply != 0, "no deposits");

        updatePool(GOV_POOL_ID);

        altRewardsPerShare[GOV_POOL_ID] = altRewardsPerShare[GOV_POOL_ID].add(
            msg.value.mul(1e12).div(lpSupply)
        );

        emit AddAltReward(msg.sender, GOV_POOL_ID, msg.value);
    }

    // Deposit LP tokens to MasterChef for GOV allocation.
    function deposit(uint256 _pid, uint256 _amount) public checkNoPause {
        poolInfo[_pid].lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        _deposit(_pid, _amount);
    }

    function _deposit(uint256 _pid, uint256 _amount) internal {
        IMasterChef.PoolInfo storage pool = poolInfo[_pid];
        IMasterChef.UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 userAmount = user.amount;
        uint256 pending;
        uint256 pendingAlt;
        if (userAmount != 0) {
            pending = userAmount
                .mul(pool.accGOVPerShare)
                .div(1e12)
                .sub(user.rewardDebt);

            // settles alt reward if any
            if (_pid == GOV_POOL_ID) {
                pendingAlt = _pendingAltRewards(msg.sender);
            }
        }

        if (_amount != 0) {
            balanceOf[_pid] = balanceOf[_pid].add(_amount);
            userAmount = userAmount.add(_amount);
            emit Deposit(msg.sender, _pid, _amount);
        }
        user.rewardDebt = userAmount.mul(pool.accGOVPerShare).div(1e12);
        user.amount = userAmount;

        safeGOVTransfer(_pid, pending);

        // claims alt reward if any
        if (pendingAlt != 0) {
            altRewardsDebt[msg.sender] = userAmount
                .mul(altRewardsPerShare[GOV_POOL_ID])
                .div(1e12);
            Address.sendValue(msg.sender, pendingAlt);
        }
    }

    function claimReward(uint256 _pid) public checkNoPause {
        _deposit(_pid, 0);
    }

    function compoundReward(uint256 _pid) public checkNoPause {
        uint256 balance = GOV.balanceOf(msg.sender);
        _deposit(_pid, 0);

        // locked pools are ignored since they auto-compound
        if (!isLocked[_pid]) {
            balance = GOV.balanceOf(msg.sender).sub(balance);
            if (balance != 0)
                deposit(GOV_POOL_ID, balance);
        }
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public checkNoPause {
        IMasterChef.PoolInfo storage pool = poolInfo[_pid];
        IMasterChef.UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 userAmount = user.amount;
        require(_amount != 0 && userAmount >= _amount, "withdraw: not good");
        updatePool(_pid);

        uint256 pending = userAmount
            .mul(pool.accGOVPerShare)
            .div(1e12)
            .sub(user.rewardDebt);

        uint256 pendingAlt;
        IERC20 lpToken = pool.lpToken;
        if (lpToken == GOV) { // _pid == GOV_POOL_ID
            uint256 availableAmount = userAmount.sub(lockedRewards[msg.sender]);
            if (_amount > availableAmount) {
                _amount = availableAmount;
            }

            // settles alt reward if any
            pendingAlt = _pendingAltRewards(msg.sender);
        }

        balanceOf[_pid] = balanceOf[_pid].sub(_amount);
        userAmount = userAmount.sub(_amount);
        user.rewardDebt = userAmount.mul(pool.accGOVPerShare).div(1e12);
        user.amount = userAmount;
        lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);

        safeGOVTransfer(_pid, pending);

        // claims alt reward if any
        if (pendingAlt != 0) {
            altRewardsDebt[msg.sender] = userAmount
                .mul(altRewardsPerShare[GOV_POOL_ID])
                .div(1e12);
            Address.sendValue(msg.sender, pendingAlt);
        }
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public checkNoPause {
        IMasterChef.PoolInfo storage pool = poolInfo[_pid];
        IMasterChef.UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 _amount = user.amount;
        IERC20 lpToken = pool.lpToken;
        if (lpToken == GOV) {
            uint256 availableAmount = _amount.sub(lockedRewards[msg.sender]);
            if (_amount > availableAmount) {
                _amount = availableAmount;
            }
        }

        lpToken.safeTransfer(address(msg.sender), _amount);
        emit EmergencyWithdraw(msg.sender, _pid, _amount);
        balanceOf[_pid] = balanceOf[_pid].sub(_amount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accGOVPerShare).div(1e12);
        if (_pid == GOV_POOL_ID) {
            altRewardsDebt[msg.sender] = user.amount
                .mul(altRewardsPerShare[GOV_POOL_ID])
                .div(1e12);
        }
    }

    function safeGOVTransfer(uint256 _pid, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }
        uint256 GOVBal = GOV.balanceOf(address(this));
        if (_amount > GOVBal) {
            _amount = GOVBal;
        }

        if (isLocked[_pid]) {
            lockedRewards[msg.sender] = lockedRewards[msg.sender].add(_amount);
            _deposit(GOV_POOL_ID, _amount);
        } else {
            GOV.transfer(msg.sender, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }


    // Custom logic - helpers


    function getPoolInfos() external view returns(IMasterChef.PoolInfo[] memory poolInfos) {
        uint256 length = poolInfo.length;
        poolInfos = new IMasterChef.PoolInfo[](length);
        for (uint256 pid = 0; pid < length; ++pid) {
            poolInfos[pid] = poolInfo[pid];
        }
    }

    function getOptimisedUserInfos(address _user) external view returns(uint256[4][] memory userInfos) {
        uint256 length = poolInfo.length;
        userInfos = new uint256[4][](length);
        for (uint256 pid = 0; pid < length; ++pid) {
            userInfos[pid][0] = userInfo[pid][_user].amount;
            userInfos[pid][1] = _pendingGOV(pid, _user);
            userInfos[pid][2] = isLocked[pid] ? 1 : 0;
            userInfos[pid][3] = pid == GOV_POOL_ID ? _pendingAltRewards(_user) : 0;
        }
    }

    function getUserInfos(address _wallet) external view returns(IMasterChef.UserInfo[] memory userInfos) {
        uint256 length = poolInfo.length;
        userInfos = new IMasterChef.UserInfo[](length);
        for (uint256 pid = 0; pid < length; ++pid) {
            userInfos[pid] = userInfo[pid][_wallet];
        }
    }

    function getPendingGOV(address _user) external view returns(uint256[] memory pending) {
        uint256 length = poolInfo.length;
        pending = new uint256[](length);
        for (uint256 pid = 0; pid < length; ++pid) {
            pending[pid] = _pendingGOV(pid, _user);
        }
    }

}