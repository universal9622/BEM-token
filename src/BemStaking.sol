//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Error
error BMS__InsufficientStake();
error BMS__InvalidDuration();

contract BemStaking {
    IERC20 public immutable tokenAddress;

    uint64 public constant MIN_DURATION = 3 * 30 days;
    uint64 public constant MAX_DURATION = 2 * 365 days;

    uint256 public totalSupply;
    uint256 public rewardRate;

    constructor() {}

    function stake(uint256 amount, uint64 duration) external {
        if (amount == 0) revert BMS__InsufficientStake();
        if (duration < MIN_DURATION || duration > MAX_DURATION)
            revert BMS__InvalidDuration();

        uint256 _totalSupply = totalSupply;
    }
}
