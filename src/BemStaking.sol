//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./lib/ABDKMath64x64.sol";
import "forge-std/console.sol";

//Error
error BMS__InsufficientStake();
error BMS__InvalidDuration();
error BMS_InsufficientBalance();
error BMS__StakeFailed();
error BMS__WithdrawFailed();
error BMS__NoRewardsAvailable();
error BMS__InvalidStaker();
error BMS__StakingPeriodNotOver();
error BMS__NoStakeAvailable();
error BMS__StakingInactive();
error BMS__AlreadyPaused();
error BMS__StakingAlreadyActive();
error BMS__StakingPeriodOverTryWithdrawal();
error BMS__StakeExitFailed();

/**
 * @title BemStaking
 * @notice This contract implements a staking mechanism for an ERC20 token. Users can stake tokens for a specified duration and earn rewards based on the staking period.
 * @dev Inherits from OpenZeppelin's AccessControl for role management. Utilizes ABDKMath64x64 for high precision arithmetic operations.
 */
contract BemStaking is AccessControl {
    IERC20 public immutable tokenAddress; // Address of the ERC20 token being staked.
    uint256 public totalSupply; // Total supply of staked tokens.
    uint256 public immutable i_rewardRate; // Immutable reward rate for staking calculations.
    bool public isActive = true; // Flag to indicate if staking is active.

    uint64 public MIN_DURATION = 3 * 30 days; // Minimum staking duration.
    uint64 public MAX_DURATION = 2 * 365 days; // Maximum staking duration.
    bytes32 public constant STAKER_ADMIN = keccak256("STAKER_ADMIN"); // Role for staking admin.
    // Struct to store information about each stake.
    struct StakeInfo {
        uint256 stakeAmount; // Amount of tokens staked.
        uint64 duration; // Duration of the stake.
        uint256 stakeBegan; // Timestamp when the stake began.
    }
    // Mapping from staker's address to their stake count and from stake count to their StakeInfo.
    mapping(address => uint32) public stakeCounts;
    mapping(address => mapping(uint32 => StakeInfo)) public stakerInfo;
    mapping(address => bool) public isStaker; // Mapping to check if an address has staked tokens.

    //Event
    event TokenStaked(
        address staker,
        uint256 amount,
        uint64 stakeBegan,
        uint64 duration,
        uint32 _counter,
        StakeInfo stakeInfo
    );
    event StakeYieldRedeemed(address staker, uint256 rewards, uint32 index);
    event StakerExited(address staker, uint _amount, StakeInfo stakeInfo);

    //Modifier
    modifier hasStake() {
        if (!isStaker[msg.sender]) revert BMS__InvalidStaker();
        _;
    }
    modifier stakingIsActive() {
        if (!isActive) revert BMS__StakingInactive();
        _;
    }

    /**
     * @notice Constructor to initialize the staking contract with the token to be staked and the admin role.
     * @param _token Address of the ERC20 token to be staked.
     * @param stakerAdmin Address to be granted the STAKER_ADMIN role.
     * @param rewardRate Annual reward rate for calculating staking rewards.
     */
    constructor(IERC20 _token, address stakerAdmin, uint256 rewardRate) {
        tokenAddress = _token;
        i_rewardRate = rewardRate;
        _grantRole(STAKER_ADMIN, stakerAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Allows users to stake tokens for a specified duration.
     * @param _amount Amount of tokens to stake.
     * @param _duration Duration for which the tokens are to be staked.
     * @dev Emits a TokenStaked event on successful staking.
     */
    function stake(uint256 _amount, uint64 _duration) public stakingIsActive {
        if (_amount == 0) revert BMS__InsufficientStake();
        if (_duration < MIN_DURATION || _duration > MAX_DURATION)
            revert BMS__InvalidDuration();
        if (tokenAddress.balanceOf(msg.sender) < _amount)
            revert BMS_InsufficientBalance();

        uint32 stakeCount = stakeCounts[msg.sender];
        StakeInfo memory stakeInfo = StakeInfo(
            _amount,
            _duration,
            block.timestamp
        );
        console.log("stakeBegan:", stakeInfo.stakeBegan);
        stakerInfo[msg.sender][stakeCount] = stakeInfo;
        stakeCounts[msg.sender] = stakeCount + 1;
        stakeCount++;
        if (!tokenAddress.transferFrom(msg.sender, address(this), _amount))
            revert BMS__StakeFailed();
        totalSupply += _amount;
        isStaker[msg.sender] = true;

        emit TokenStaked(
            msg.sender,
            _amount,
            uint64(block.timestamp),
            _duration,
            stakeCount,
            stakeInfo
        );
    }

    /**
     * @notice Allows a staker to exit staking by withdrawing their staked tokens.
     * @dev Emits a StakerExited event on successful withdrawal of staked tokens.
     * This function checks that the caller has an active stake, verifies if the staking period
     * has ended, and then transfers the staked amount back to the caller. The staked amount is
     * then reset to 0 to prevent re-entrancy or duplicate withdrawals.
     *
     * Requirements:
     * - The caller must have an active stake.
     * - The staking period for the latest stake must be over.
     *
     * @custom:modifier hasStake Ensures the caller has an active stake.
     */
    function exit() external hasStake {
        uint32 index = stakeCounts[msg.sender];
        StakeInfo memory exitInfo = stakerInfo[msg.sender][index];
        if (exitInfo.stakeAmount > 0) revert BMS__NoStakeAvailable();
        if (block.timestamp > exitInfo.duration)
            revert BMS__StakingPeriodOverTryWithdrawal();

        uint256 exitAmount = exitInfo.stakeAmount;
        exitInfo.stakeAmount = 0;
        // exitInfo.duration = 0;
        // exitInfo.stakeBegan = 0;
        exitInfo = StakeInfo(0, 0, 0);
        if (!tokenAddress.transferFrom(address(this), msg.sender, exitAmount))
            revert BMS__StakeExitFailed();
        emit StakerExited(msg.sender, exitAmount, exitInfo);
    }

    /**
     * @notice Allows a staker to withdraw their rewards after the staking period is over.
     * @dev Emits a StakeYieldRedeemed event on successful withdrawal of rewards.
     * This function checks if the staking period for the caller's latest stake has ended,
     * calculates the rewards using `_getStakeRewards`, and transfers the rewards to the caller.
     * It then resets the stake start time to allow for recalculating rewards for subsequent periods.
     */
    function withdraw() public hasStake {
        uint32 index = stakeCounts[msg.sender];
        StakeInfo memory currentStaker = stakerInfo[msg.sender][index];
        if (block.timestamp - currentStaker.stakeBegan < currentStaker.duration)
            revert BMS__StakingPeriodNotOver();

        uint256 rewards = _getStakeRewards();
        if (rewards <= 0) revert BMS__NoRewardsAvailable();
        currentStaker.stakeBegan = uint64(block.timestamp);
        if (!tokenAddress.transferFrom(msg.sender, address(this), rewards))
            revert BMS__WithdrawFailed();

        emit StakeYieldRedeemed(msg.sender, rewards, index);
    }

    /**
     * @notice Pauses the staking functionality, preventing new stakes.
     * @dev Can only be called by an account with the STAKER_ADMIN role.
     * @return bool Returns true if staking is successfully paused.
     */
    function pauseStaking() public onlyRole(STAKER_ADMIN) returns (bool) {
        if (!isActive) revert BMS__AlreadyPaused();
        isActive = false;
        return isActive;
    }

    /**
     * @notice Restarts the staking functionality, allowing new stakes.
     * @dev Can only be called by an account with the STAKER_ADMIN role.
     * @return bool Returns true if staking is successfully restarted.
     */
    function restartStaking() public onlyRole(STAKER_ADMIN) returns (bool) {
        if (isActive) revert BMS__StakingAlreadyActive();
        isActive = false;
        return isActive;
    }

    /**
     * @notice Grants the STAKER_ADMIN role to a specified account.
     * @param admin The address to be granted the STAKER_ADMIN role.
     * @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function grantStakeAdminRole(
        address admin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(STAKER_ADMIN, admin);
    }

    /**
     * @notice Revokes the STAKER_ADMIN role from a specified account.
     * @param _admin The address from which the STAKER_ADMIN role will be revoked.
     * @dev Can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function revokeStakeAdminRole(
        address _admin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(STAKER_ADMIN, _admin);
    }

    /**
     * @notice Calculates and returns the staking rewards for a staker.
     * @return uint256 The calculated staking rewards.
     * @dev Uses ABDKMath64x64 library for precise calculation of compounding rewards.
     */
    function _getStakeRewards() internal view returns (uint256) {
        uint32 index = stakeCounts[msg.sender];
        StakeInfo memory thisStake = stakerInfo[msg.sender][index];
        if (block.timestamp < (thisStake.stakeBegan + thisStake.duration)) {
            return 0;
        }
        uint256 stakingDuration = uint64(block.timestamp) -
            thisStake.stakeBegan;
        if (stakingDuration > 0 && i_rewardRate > 0) {
            int128 compoundingFactor = ABDKMath64x64.pow(
                ABDKMath64x64.add(
                    ABDKMath64x64.fromUInt(1),
                    ABDKMath64x64.div(
                        ABDKMath64x64.fromUInt(i_rewardRate),
                        ABDKMath64x64.fromUInt(365)
                    )
                ),
                stakingDuration / 1 days
            );
            return
                ABDKMath64x64.mulu(compoundingFactor, thisStake.stakeAmount) -
                thisStake.stakeAmount;
        }
        return 0;
    }
}
