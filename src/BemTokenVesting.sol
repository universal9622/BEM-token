// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
//anvil --fork-url https://eth-sepolia.g.alchemy.com/v2/fWr3m1Bq4Mqxz0n-WoE86aq24VsXTsrq

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Custom errors for specific failure cases
error BTV__InSufficientTokenToVest();
error BTV__VestingAlreadySet();
error BTV__InvalidMerkleProof();
error BTV__NotOwnerOrReleasor();
error BTV__NoTokenToVest();
error BTV__AlreadyClaimed();
error BTV__NothingToRelease();
error BTV__TokenNonExistent();

/// @title Presale Token Vesting
/// @notice Manages the vesting of tokens purchased during a presale event, based on predefined vesting schedules.
/// @dev Utilizes Merkle Proofs for initial allocation validation, ensuring participants' allocations match the presale terms.
contract PresaleTokenVesting is Ownable {
    IERC20 private immutable _token;

    bytes32 public immutable i_merkleRoot; // Root hash of the Merkle tree used to validate vesting proofs.

    // Constants defining the vesting schedule parameters.
    uint256 public constant VESTING_DURATION = 2 * 365 days; // Total duration of the vesting period.
    uint256 public constant FIRST_UNLOCK = 6 * 30 days; // Duration until the first unlock of tokens.
    uint256 public constant SECOND_UNLOCK = 12 * 30 days; // Duration until the second unlock of tokens.
    uint256 public constant THIRD_UNLOCK = 15 * 30 days; // Duration until the third unlock of tokens.
    uint256 public constant FOURTH_UNLOCK = 18 * 30 days; // Duration until the fourth and final unlock of tokens.

    struct VestingInfo {
        address beneficiary; // Address of the beneficiary who is entitled to the tokens.
        uint256 totalAmount; // Total amount of tokens allocated for vesting to the beneficiary.
        uint256 amountReleased; // Amount of tokens that have been released to the beneficiary so far.
        uint256 vestingStart; // Timestamp when the vesting period starts.
    }

    mapping(bytes32 => VestingInfo) public vestingInformation;
    mapping(address => uint256) private holdersVestingCount;

    /// @notice Emitted when tokens are released to a beneficiary
    event TokensReleased(address beneficiary, uint256 amount);

    /// @notice Emitted when a new vesting schedule is created
    event VestCreated(
        address holder,
        uint256 amount,
        uint256 vestStartTime,
        bytes32 vetsingScheduleId,
        VestingInfo initialVest
    );

    /// @dev Sets the token contract and the merkle root used for vesting verification
    /// @param tokenAddress The ERC20 token contract address
    /// @param merkleRoot The root hash of the Merkle tree used for allocation verification
    constructor(IERC20 tokenAddress, bytes32 merkleRoot) Ownable(msg.sender) {
        if (address(tokenAddress) == address(0)) revert BTV__TokenNonExistent();
        _token = tokenAddress;
        i_merkleRoot = merkleRoot;
    }

    /// @notice Sets up a vesting schedule for a beneficiary using a Merkle Proof for verification
    /// @param _beneficiary The address of the beneficiary to receive the vested tokens
    /// @param totalAmount The total amount of tokens to be vested
    /// @param merkleProof The Merkle Proof verifying the allocation
    /// @dev Only the owner can set up a vesting schedule
    function setVesting(
        address _beneficiary,
        uint256 totalAmount,
        bytes32[] calldata merkleProof
    ) external onlyOwner {
        bytes32 vestingScheduleId;
        if (totalAmount <= 0) revert BTV__InSufficientTokenToVest();
        if (vestingInformation[vestingScheduleId].totalAmount != 0)
            revert BTV__VestingAlreadySet();

        // Compute the leaf node by hashing the beneficiary and total amount
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(_beneficiary, totalAmount)))
        );

        // Verify the provided Merkle Proof against the stored Merkle Root
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf))
            revert BTV__InvalidMerkleProof();

        vestingScheduleId = computeVestingScheduleIdForHolder(_beneficiary);
        console.log("beneficiary:", _beneficiary);
        console.logBytes32(vestingScheduleId);
        vestingInformation[vestingScheduleId] = VestingInfo(
            _beneficiary,
            totalAmount,
            0,
            getCurrentTime()
        );
        uint256 vestCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = vestCount + 1;

        emit VestCreated(
            _beneficiary,
            totalAmount,
            getCurrentTime(),
            vestingScheduleId,
            vestingInformation[vestingScheduleId]
        );
    }

    /// @dev Computes a unique identifier for a vesting schedule based on the beneficiary's address and their vest count
    function computeVestingScheduleIdForHolder(
        address _beneficiary
    ) public view returns (bytes32) {
        return
            computeVestingScheduleIdForAddressNIndex(
                _beneficiary,
                holdersVestingCount[_beneficiary]
            );
    }

    /// @dev Generates a unique identifier for a vesting schedule using the beneficiary's address and a specific index
    function computeVestingScheduleIdForAddressNIndex(
        address holder,
        uint256 index
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /// @notice Releases vested tokens to the beneficiary
    /// @param vestScheduleId The unique identifier of the vesting schedule
    /// @dev Can be called by the beneficiary or the owner
    function release(bytes32 vestScheduleId) external {
        console.log("releaseCaller:", msg.sender);
        bool isHolder = msg.sender ==
            vestingInformation[vestScheduleId].beneficiary;
        // bool isReleasor = (msg.sender == owner());
        if (!isHolder) revert BTV__NotOwnerOrReleasor();

        VestingInfo storage vesting = vestingInformation[vestScheduleId];
        if (vesting.totalAmount <= 0) revert BTV__NoTokenToVest();
        if (vesting.totalAmount == vesting.amountReleased)
            revert BTV__AlreadyClaimed();

        uint256 unreleased = releasableAmount(vestScheduleId);
        if (unreleased <= 0) revert BTV__NothingToRelease();

        vesting.amountReleased += unreleased;
        _token.approve(address(this), unreleased);
        require(
            _token.transferFrom(address(this), msg.sender, unreleased),
            "Token release failed"
        );

        emit TokensReleased(msg.sender, unreleased);
    }

    /// @dev Calculates the amount of tokens that can be released from vesting
    function releasableAmount(
        bytes32 vestingScheduleId
    ) public view returns (uint256) {
        VestingInfo memory vesting = vestingInformation[vestingScheduleId];
        uint256 totalVested = vestedAmount(vestingScheduleId);
        return totalVested - vesting.amountReleased;
    }

    /// @dev Determines the amount of vested token to unlock to the pre-sale contributor based on the current time and the vesting schedule
    function vestedAmount(
        bytes32 vestingScheduleId
    ) internal view returns (uint256) {
        VestingInfo memory vesting = vestingInformation[vestingScheduleId];
        uint256 elapsedTime = getCurrentTime() - vesting.vestingStart;
        uint256 totalAmount = vesting.totalAmount;

        if (elapsedTime < FIRST_UNLOCK) {
            return 0; // No tokens are unlocked in the first 6 months
        } else if (elapsedTime >= FIRST_UNLOCK && elapsedTime < SECOND_UNLOCK) {
            return (totalAmount * 25) / 100; // 25% unlocked after 6 months
        } else if (elapsedTime >= SECOND_UNLOCK && elapsedTime < THIRD_UNLOCK) {
            return (totalAmount * 50) / 100; // An additional 25% unlocked after 12 months, making 50% in total
        } else if (elapsedTime >= THIRD_UNLOCK && elapsedTime < FOURTH_UNLOCK) {
            return (totalAmount * 75) / 100; // Another 25% unlocked after 15 months, making 75% in total
        } else if (elapsedTime >= FOURTH_UNLOCK) {
            return (totalAmount * 100) / 100; // Final 25% unlocked after 18 months, making 100% in total
        } else {
            return totalAmount; // Fallback to total amount if above conditions are not met
        }
    }

    /// @dev Utility function to obtain the current block timestamp
    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function getVestingInfo(
        bytes32 vestingScheduleId
    ) external view returns (VestingInfo memory) {
        return vestingInformation[vestingScheduleId];
    }
}

/**
 *     function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(_token), "Cannot recover vested tokens");

        uint256 recoverableAmount = IERC20(tokenAddress).balanceOf(address(this));
        require(tokenAmount <= recoverableAmount, "Insufficient recoverable amount");

        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);

        emit RecoveredERC20(tokenAddress, tokenAmount);
    }
 */
