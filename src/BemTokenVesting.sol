// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error BTV__InSufficientTokenToVest();
error BTV__VestingAlreadySet();
error BTV__InvalidMerkleProof();

contract PresaleTokenVesting is Ownable {
    IERC20 private immutable _token;

    struct VestingInfo {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 vestingStart;
    }
    bytes32 public immutable i_merkleRoot;
    // Vesting parameters
    uint256 public constant VESTING_DURATION = 2 * 365 days; // 2 years in total
    uint256 public constant FIRST_PHASE_DURATION = 6 * 30 days; // First 6 months
    uint256 public constant SECOND_PHASE_DURATION = 3 * 30 days; // Second 6 months
    uint256 public constant UNLOCK_AMOUNT = 25;

    mapping(address => VestingInfo) public vestingInformation;

    event TokensReleased(address beneficiary, uint256 amount);

    constructor(IERC20 tokenAddress, bytes32 merkleRoot) Ownable(msg.sender) {
        require(
            address(tokenAddress) != address(0),
            "TokenVesting: token is the zero address"
        );
        _token = tokenAddress;
        i_merkleRoot = merkleRoot;
    }

    function setVesting(
        address beneficiary,
        uint256 totalAmount,
        bytes32[] calldata merkleProof
    ) external onlyOwner {
        // require(totalAmount > 0, "PresaleTokenVesting: Cannot vest 0 tokens");
        // require(
        //     vestingInformation[beneficiary].totalAmount == 0,
        //     "PresaleTokenVesting: Vesting already set for beneficiary"
        // );
        if (totalAmount <= 0) revert BTV__InSufficientTokenToVest();
        if (vestingInformation[beneficiary].totalAmount != 0)
            revert BTV__VestingAlreadySet();

        bytes32 leaf = keccak256(abi.encodePacked(beneficiary, totalAmount));

        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf))
            revert BTV__InvalidMerkleProof();
        vestingInformation[beneficiary] = VestingInfo({
            totalAmount: totalAmount,
            amountReleased: 0,
            vestingStart: block.timestamp
        });
    }

    function release() external {
        VestingInfo storage vesting = vestingInformation[msg.sender];
        require(
            vesting.totalAmount > 0,
            "PresaleTokenVesting: No tokens to vest"
        );

        uint256 unreleased = releasableAmount(msg.sender);
        require(
            unreleased > 0,
            "PresaleTokenVesting: No tokens are due for release"
        );

        vesting.amountReleased += unreleased;
        _token.transfer(msg.sender, unreleased);

        emit TokensReleased(msg.sender, unreleased);
    }

    function releasableAmount(
        address beneficiary
    ) public view returns (uint256) {
        VestingInfo memory vesting = vestingInformation[beneficiary];
        uint256 totalVested = vestedAmount(beneficiary);
        return totalVested - vesting.amountReleased;
    }

    function vestedAmount(address beneficiary) public view returns (uint256) {
        VestingInfo memory vesting = vestingInformation[beneficiary];
        uint256 elapsedTime = block.timestamp - vesting.vestingStart;
        uint256 totalAmount = vesting.totalAmount;

        if (elapsedTime < FIRST_PHASE_DURATION) {
            return (totalAmount * UNLOCK_AMOUNT) / 100;
        } else if (elapsedTime < (FIRST_PHASE_DURATION * 2)) {
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
        } else {
            return totalAmount;
        }
    }
}
