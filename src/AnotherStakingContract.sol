//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/FullMath.sol";

//Error
error BMS__InsufficientStake();
error BMS__InvalidDuration();
error BMS__StakeFailed();
error BMS__WithdrawFailed();
error BMS__NotRewardsAvailable();
error BMS__InvalidStaker();

contract BemStaking {
    IERC20 public immutable tokenAddress;

    uint64 public minDuration = uint64(block.timestamp) + (3 * 30 days);
    uint64 public maxDuration = uint64(block.timestamp) + (2 * 365 days);
    uint256 public constant PRECISION = 1e30;

    uint256 public totalSupply;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;
    uint64 public lastUpdateTime;

    //Mapping
    mapping(address => bool) public isStaker;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public stakeRewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    //Event
    event TokenStaked(
        address staker,
        uint256 amount,
        uint64 duration,
        uint256 rewardRate
    );
    event TokenStakeWithdrawn(address staker, uint256 stakeAmount);
    event StakeYieldRedeemed(address staker, uint256 yield);

    //Modifier
    modifier hasStake() {
        if (!isStaker[msg.sender]) revert BMS__InvalidStaker();
        _;
    }

    constructor(IERC20 _token) {
        tokenAddress = _token;
    }

    function stake(uint256 amount, uint64 duration) external {
        if (amount == 0) revert BMS__InsufficientStake();
        if (duration < minDuration || duration > maxDuration)
            revert BMS__InvalidDuration();

        uint256 userStakeBalance = balanceOf[msg.sender];
        uint64 recentStakeDurationUpdate = getLatestStakeTimeFromStart();
        uint256 _totalSupply = totalSupply;
        uint256 rewardPerToken = _getRewardPerToken(
            recentStakeDurationUpdate,
            _totalSupply
        );
        rewardPerTokenStored = rewardPerToken;
        lastUpdateTime = recentStakeDurationUpdate;
        balanceOf[msg.sender] = userStakeBalance + amount;
        stakeRewards[msg.sender] = _earned(
            msg.sender,
            userStakeBalance,
            rewardPerToken,
            stakeRewards[msg.sender]
        );
        userRewardPerTokenPaid[msg.sender] = rewardPerToken;

        totalSupply = _totalSupply + totalSupply;
        if (!tokenAddress.transferFrom(msg.sender, address(this), amount))
            revert BMS__StakeFailed();

        isStaker[msg.sender] = true;

        emit TokenStaked(msg.sender, amount, duration, rewardRate);
    }

    function withdraw(uint256 amount) external hasStake {
        if (amount == 0) revert BMS__InsufficientStake();

        uint256 userStakeBalance = balanceOf[msg.sender];
        uint64 recentStakeDurationUpdate = getLatestStakeTimeFromStart();
        uint256 _totalSupply = totalSupply;

        uint256 rewardPerToken = _getRewardPerToken(
            recentStakeDurationUpdate,
            _totalSupply
        );
        rewardPerTokenStored = rewardPerToken;

        lastUpdateTime = recentStakeDurationUpdate;

        stakeRewards[msg.sender] = _earned(
            msg.sender,
            userStakeBalance,
            rewardPerToken,
            stakeRewards[msg.sender]
        );

        userRewardPerTokenPaid[msg.sender] = rewardPerToken;

        balanceOf[msg.sender] = userStakeBalance - amount;

        unchecked {
            totalSupply = _totalSupply - amount;
        }

        if (!tokenAddress.transferFrom(address(this), msg.sender, amount))
            revert BMS__WithdrawFailed();

        emit TokenStakeWithdrawn(msg.sender, amount);
    }

    function exit() public hasStake {
        uint256 stakeBalance = balanceOf[msg.sender];

        uint64 recentStakeDurationUpdate = getLatestStakeTimeFromStart();
        uint256 _totalSupply = totalSupply;
        uint256 rewardPerToken = _getRewardPerToken(
            recentStakeDurationUpdate,
            _totalSupply
        );

        uint256 rewards = _earned(
            msg.sender,
            stakeBalance,
            rewardPerToken,
            stakeRewards[msg.sender]
        );
        if (rewards > 0) {
            stakeRewards[msg.sender] = 0;
        }

        rewardPerTokenStored = rewardPerToken;
        lastUpdateTime = recentStakeDurationUpdate;
        userRewardPerTokenPaid[msg.sender] = rewardPerToken;

        balanceOf[msg.sender] = 0;

        tokenAddress.transferFrom(address(this), msg.sender, stakeBalance);
        emit TokenStakeWithdrawn(msg.sender, stakeBalance);

        unchecked {
            totalSupply = _totalSupply - stakeBalance;
        }
        if (rewards > 0) {
            tokenAddress.transferFrom(address(this), msg.sender, rewards);
            emit StakeYieldRedeemed(msg.sender, rewards);
        }
    }

    function getReward() external hasStake {
        uint256 stakeBalance = balanceOf[msg.sender];
        uint256 _totalSupply = totalSupply;
        uint64 latestStakeDurationUpdate = getLatestStakeTimeFromStart();
        uint256 rewardPerToken = _getRewardPerToken(
            latestStakeDurationUpdate,
            _totalSupply
        );
        rewardPerTokenStored = rewardPerToken;
        lastUpdateTime = latestStakeDurationUpdate;
        uint256 rewards = _earned(
            msg.sender,
            stakeBalance,
            rewardPerToken,
            stakeRewards[msg.sender]
        );
        if (rewards <= 0) {
            revert BMS__NotRewardsAvailable();
        } else if (rewards > 0) {
            stakeRewards[msg.sender] = 0;
        }

        tokenAddress.transferFrom(address(this), msg.sender, rewards);
    }

    function getRewardPerToken() public view returns (uint256) {
        return _getRewardPerToken(getLatestStakeTimeFromStart(), totalSupply);
    }

    function earned(address staker) public view returns (uint256) {
        return
            _earned(
                staker,
                balanceOf[staker],
                _getRewardPerToken(getLatestStakeTimeFromStart(), totalSupply),
                stakeRewards[staker]
            );
    }

    function _getRewardPerToken(
        uint64 latestStakeTimeFromStart,
        uint256 _totalSupply
    ) internal view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            FullMath.mulDiv(rewardRate, latestStakeTimeFromStart, _totalSupply);
    }

    function _earned(
        address account,
        uint256 userStakeAmount,
        uint256 rewardPerToken,
        uint256 prevRewards
    ) internal view returns (uint256) {
        return
            FullMath.mulDiv(
                userStakeAmount,
                rewardPerToken - userRewardPerTokenPaid[account],
                PRECISION
            ) + prevRewards;
    }

    function getLatestStakeTimeFromStart() private view returns (uint64) {
        if (block.timestamp < minDuration) {
            return minDuration;
        } else if (
            block.timestamp < maxDuration && block.timestamp > minDuration
        ) {
            return maxDuration;
        } else {
            return uint64(block.timestamp);
        }
    }
}
