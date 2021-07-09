pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/// SPDX-License-Identifier: MIT
import "../GovToken.sol";


interface IMasterChef {

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of GOVs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accGOVPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accGOVPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. GOVs to distribute per block.
        uint256 lastRewardBlock; // Last block number that GOVs distribution occurs.
        uint256 accGOVPerShare; // Accumulated GOVs per share, times 1e12. See below.
    }

    function GOV()
        external
        view
        returns (GovToken);

    // Block number when bonus GOV period ends.
    function bonusEndBlock()
        external
        view
        returns(uint256);

    // GOV tokens created per block.
    function GOVPerBlock()
        external
        view
        returns(uint256);

    // Bonus muliplier for early GOV makers.
    function BONUS_MULTIPLIER()
        external
        view
        returns(uint256);

    // unused
    function migrator()
        external
        view
        returns(address);

    // Info of each pool.
    function poolInfo(uint256)
        external
        view
        returns (PoolInfo memory);

    // Info of each user that stakes LP tokens.
    function userInfo(uint256, address)
        external
        view
        returns (UserInfo memory);

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    function totalAllocPoint()
        external
        view
        returns(uint256);

    // The block number when GOV mining starts.
    function startBlock()
        external
        view
        returns (uint256);

    function poolExists(IERC20) external view returns (bool);

    // total deposits in a pool
    function balanceOf(uint256)
        external
        view
        returns (uint256);

    // pool rewards locked for future claim
    function isLocked(uint256)
        external
        view
        returns (bool);

    // total locked rewards for a user
    function lockedRewards(address)
        external
        view
        returns (uint256);

    function isPaused()
        external
        view
        returns(bool);

    function poolLength()
        external
        view
        returns (uint256);

    function owner()
        external
        view
        returns(address);

    function addExternalReward(uint256 _amount)
        external;

    function getMultiplier(uint256 _from, uint256 _to)
        external
        view
        returns (uint256);

    function getMultiplierNow()
        external
        view
        returns (uint256);

    function getMultiplierPrecise(uint256 _from, uint256 _to)
        external
        view
        returns (uint256);

    // View function to see pending GOVs on frontend.
    function pendingGOV(uint256 _pid, address _user)
        external
        view
        returns (uint256);

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools()
        external;

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid)
        external;

    // Deposit LP tokens to MasterChef for GOV allocation.
    function deposit(uint256 _pid, uint256 _amount)
        external;

    function claimReward(uint256 _pid)
        external;

    function compoundReward(uint256 _pid)
        external;

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount)
        external;

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid)
        external;

    // Update dev address by the previous dev.
    function dev(address _devaddr)
        external;

    // Custom logic - helpers
    function getPoolInfos() external view returns(PoolInfo[] memory);

    function getOptimisedUserInfos(address _user)
        external
        view
        returns(uint256[3][] memory);

    function getUserInfos(address _wallet)
        external
        view
        returns(UserInfo[] memory);

    function getPendingGOV(address _user)
        external
        view
        returns(uint256[] memory);

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Withdraw(address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event AddExternalReward(
        address indexed sender,
        uint256 indexed pid,
        uint256 amount
    );
}