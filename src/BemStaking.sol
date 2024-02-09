//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Error
error BMS__InsufficientStake();
error BMS__InvalidDuration();
error BMS__StakeFailed();

contract BemStaking {
    IERC20 public immutable tokenAddress;

    uint64 public constant MIN_DURATION = 3 * 30 days;
    uint64 public constant MAX_DURATION = 2 * 365 days;

    uint256 public totalSupply;
    uint256 public rewardRate;

    //Mapping
    mapping(address => uint256) public stakeRewards;

    //Event
    event TokenStaked(address staker, uint256 amount, uint64 duration);

    constructor(IERC20 _token) {
        tokenAddress = _token;
    }

    function stake(uint256 amount, uint64 duration) external {
        if (amount == 0) revert BMS__InsufficientStake();
        if (duration < MIN_DURATION || duration > MAX_DURATION)
            revert BMS__InvalidDuration();

        uint256 _totalSupply = totalSupply;
        uint64 getRecentStakeDurationUpdate = getLatestStakeTimeFromStart();
        // uint256 rewardPerToken=
        if (!tokenAddress.transferFrom(msg.sender, address(this), amount))
            revert BMS__StakeFailed();

        emit TokenStaked(msg.sender, amount, duration);
    }

    function _getTokenReward() internal returns (uint256) {}

    function getLatestStakeTimeFromStart() private returns (uint64) {
        if (block.timestamp < MIN_DURATION) {
            return MIN_DURATION;
        } else if (block.timestamp < MAX_DURATION) {
            return MAX_DURATION;
        } else {
            return uint64(block.timestamp);
        }
    }
}
