// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error BTV__InSufficientTokenToVest();
error BTV__VestingAlreadySet();
error BTV__InvalidMerkleProof();
error BTV__NotOwnerOrReleasor();
error BTV__NoTokenToVest();
error BTV__AlreadyClaimed();
error BTV__NothingToRelease();

contract PresaleTokenVesting is Ownable {
    IERC20 private immutable _token;

    struct VestingInfo {
        address beneficiary;
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 vestingStart;
    }
    bytes32 public immutable i_merkleRoot;
    // Vesting parameters
    uint256 public constant VESTING_DURATION = 2 * 365 days; // 2 years in total
    uint256 public constant FIRST_PHASE_DURATION = 6 * 30 days; // First 6 months & the next 6 months
    uint256 public constant SECOND_PHASE_DURATION = 12 * 30 days; //
    uint256 public constant THIRD_PHASE_DURATION = 15 * 30 days; //
    uint256 public constant FOURTH_PHASE_DURATION = 18 * 30 days; //

    uint256 public constant UNLOCK_AMOUNT = 25;

    mapping(bytes32 => VestingInfo) public vestingInformation;
    mapping(address => uint256) private holdersVestingCount;

    event TokensReleased(address beneficiary, uint256 amount);
    event VestCreated(address holder, uint256 amount, uint256 vestStartTime);

    constructor(IERC20 tokenAddress, bytes32 merkleRoot) Ownable(msg.sender) {
        require(
            address(tokenAddress) != address(0),
            "TokenVesting: token is the zero address"
        );
        _token = tokenAddress;
        i_merkleRoot = merkleRoot;
    }

    function setVesting(
        address _beneficiary,
        uint256 totalAmount,
        bytes32[] calldata merkleProof
    ) external onlyOwner {
        bytes32 vestingScheduleId;
        if (totalAmount <= 0) revert BTV__InSufficientTokenToVest();
        if (vestingInformation[vestingScheduleId].totalAmount != 0)
            revert BTV__VestingAlreadySet();

        bytes32 leaf = keccak256(abi.encodePacked(_beneficiary, totalAmount));

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf))
            revert BTV__InvalidMerkleProof();

        vestingScheduleId = computetVestingScheduleIdForHolder(_beneficiary);
        vestingInformation[vestingScheduleId] = VestingInfo({
            beneficiary: _beneficiary,
            totalAmount: totalAmount,
            amountReleased: 0,
            vestingStart: block.timestamp
        });
        uint256 vestCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = vestCount + 1;

        emit VestCreated(_beneficiary, totalAmount, block.timestamp);
    }

    function computetVestingScheduleIdForHolder(
        address _beneficiary
    ) public view returns (bytes32) {
        return
            computeVestingScheduleIdForAddressNIndex(
                _beneficiary,
                holdersVestingCount[_beneficiary]
            );
    }

    function computeVestingScheduleIdForAddressNIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    function release(bytes32 vestScheduleId) external {
        bool isHolder = msg.sender ==
            vestingInformation[vestScheduleId].beneficiary;
        bool isReleasor = (msg.sender == owner());
        if (!isHolder || !isReleasor) revert BTV__NotOwnerOrReleasor();

        VestingInfo storage vesting = vestingInformation[vestScheduleId];
        if (vesting.totalAmount <= 0) revert BTV__NoTokenToVest();
        if (vesting.totalAmount == vesting.amountReleased)
            revert BTV__AlreadyClaimed();

        uint256 unreleased = releasableAmount(vestScheduleId);
        if (unreleased < 0) revert BTV__NothingToRelease();

        vesting.amountReleased += unreleased;
        require(
            _token.transfer(msg.sender, unreleased),
            "Token release failed"
        );

        emit TokensReleased(msg.sender, unreleased);
    }

    function releasableAmount(
        bytes32 vestingScheduleId
    ) public view returns (uint256) {
        VestingInfo memory vesting = vestingInformation[vestingScheduleId];
        uint256 totalVested = vestedAmount(vestingScheduleId);
        return totalVested - vesting.amountReleased;
    }

    function vestedAmount(
        bytes32 vestingScheduleId
    ) public view returns (uint256) {
        VestingInfo memory vesting = vestingInformation[vestingScheduleId];
        uint256 elapsedTime = block.timestamp - vesting.vestingStart;
        uint256 totalAmount = vesting.totalAmount;

        if (elapsedTime < FIRST_PHASE_DURATION) {
            return 0;
        } else if (
            (elapsedTime >= FIRST_PHASE_DURATION &&
                elapsedTime < SECOND_PHASE_DURATION) ||
            (elapsedTime >= SECOND_PHASE_DURATION &&
                elapsedTime < THIRD_PHASE_DURATION) ||
            (elapsedTime >= THIRD_PHASE_DURATION &&
                elapsedTime < FOURTH_PHASE_DURATION) ||
            (elapsedTime >= FOURTH_PHASE_DURATION)
        ) {
            return (totalAmount * (UNLOCK_AMOUNT)) / 100;
        } else {
            return totalAmount;
        }
    }

    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}

/**
 * if (elapsedTime < FIRST_PHASE_DURATION) {
            return 0;
        } else if (
            elapsedTime >= FIRST_PHASE_DURATION &&
            elapsedTime < SECOND_PHASE_DURATION
        ) {
            return (totalAmount * (UNLOCK_AMOUNT + UNLOCK_AMOUNT)) / 100;
        } else if (
            elapsedTime >= SECOND_PHASE_DURATION &&
            elapsedTime < THIRD_PHASE_DURATION
        ) {
            return (totalAmount * (UNLOCK_AMOUNT + UNLOCK_AMOUNT)) / 100;
        } else if (
            elapsedTime >= THIRD_PHASE_DURATION &&
            elapsedTime < FOURTH_PHASE_DURATION
        ) {
            return (totalAmount * (UNLOCK_AMOUNT + UNLOCK_AMOUNT)) / 100;
        } else if (elapsedTime < VESTING_DURATION) {
            // Calculate releases for phases 3 and 4 based on the quarter
            uint256 quartersElapsed = (elapsedTime -
                FIRST_PHASE_DURATION -
                SECOND_PHASE_DURATION) / (3 * 30 days);
            uint256 totalReleasePercentage = UNLOCK_AMOUNT +
                UNLOCK_AMOUNT +
                (quartersElapsed * UNLOCK_AMOUNT);
            return (totalAmount * totalReleasePercentage) / 100;
        }
 */
