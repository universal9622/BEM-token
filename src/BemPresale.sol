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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./lib/ABDKMath64x64.sol";

//Error
error BEM__PresaleInactive();
error BEM__InvalidPurchaseAmount();
error BEM__PresaleCapExceeded();
error BEM__MaxAccumulationLimitExceeded();
error BEM__ZeroEtherToWithdraw();
error BEM__PresaleCapCantBeZero();
error BEM__MaxPurchaseCantBeZero();
error BEM__PurchaseCapCantBeZero();
error BEM__TokenNonExistent();
//Airdrop errors
error BM__InvalidAddress();
error BM__InvalidAmount();
error BM_InvalidMerkleProof();
error BM__AirDropFailed();

/// @title BemPresale
/// @notice This contract manages the presale of BEM tokens, allowing users to contribute ETH in exchange for BEM tokens.
/// @dev The contract uses OpenZeppelin's IERC20 interface for ERC20 token interactions and Ownable for ownership management.
/// Custom errors are defined for handling specific failure cases gracefully.

contract BemPresale is Ownable {
    IERC20 private immutable _token;
    AggregatorV3Interface private priceFeed;

    bytes32 public immutable i_merkleRoot;

    uint256 public constant tokenPriceUsd = 0.0075 * 1e18; //$0.0075

    uint256 public immutable i_presaleCap;
    uint256 public immutable i_presaleMinPurchase;
    uint256 public immutable i_presaleMaxPurchase;

    bool public isPresaleActive;
    uint256 public presaleRaisedAmount;

    //mapping
    // Mapping to track ETH deposits by contributors.
    mapping(address => uint256) public saleDeposit;
    // Mapping to track the amount of BEM tokens allocated to each contributor.
    mapping(address => uint256) public addressToPresaleAmount;

    //Event
    /// @notice Emitted when a contribution is made to the presale.
    /// @param contributor The address of the contributor.
    /// @param amount The amount of ETH contributed.
    /// @param tokensAllocated The amount of BEM tokens allocated to the contributor.
    event PresaleContribution(
        address indexed contributor,
        uint256 amount,
        uint256 tokensAllocated
    );
    /// @notice Emitted when tokens are withdrawn by the owner.
    /// @param _receiver The address receiving the tokens.
    /// @param _amount The amount of tokens withdrawn.
    event TokensWithdrawn(address _receiver, uint256 _amount);

    event AirDrop(address source, address destination, uint256 _amount);

    /// @dev Sets the initial conditions for the presale.
    /// @param presaleCap The maximum amount of ETH that can be raised.
    /// @param presaleMinPurchase The minimum contribution amount in ETH.
    /// @param presaleMaxPurchase The maximum contribution amount in ETH per contributor.
    /// @param tokenAddress The address of the BEM ERC20 token.
    constructor(
        uint256 presaleCap,
        uint256 presaleMinPurchase,
        uint256 presaleMaxPurchase,
        IERC20 tokenAddress,
        bytes32 merkleRoot
    ) Ownable(msg.sender) {
        if (presaleCap <= 0) revert BEM__PresaleCapCantBeZero();
        if (presaleMaxPurchase <= 0 || presaleMaxPurchase <= 0)
            revert BEM__PurchaseCapCantBeZero();
        if (address(tokenAddress) == address(0)) revert BEM__TokenNonExistent();

        priceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        isPresaleActive = true;
        i_merkleRoot = merkleRoot;
        i_presaleCap = presaleCap;
        i_presaleMinPurchase = presaleMinPurchase;
        i_presaleMaxPurchase = presaleMaxPurchase;
        _token = tokenAddress;
    }

    /// @notice Allows contributors to send ETH and participate in the presale.
    /// @dev Reverts if the presale is inactive, the contribution is outside the allowed range, the presale cap is exceeded, or if the contributor has reached the max accumulation limit.
    function contributeToPresale() public payable {
        if (!isPresaleActive) revert BEM__PresaleInactive();
        if (addressToPresaleAmount[msg.sender] >= i_presaleMaxPurchase)
            revert BEM__MaxAccumulationLimitExceeded();
        if (
            msg.value < i_presaleMinPurchase || msg.value > i_presaleMaxPurchase
        ) revert BEM__InvalidPurchaseAmount();
        if (i_presaleCap == presaleRaisedAmount)
            revert BEM__PresaleCapExceeded();

        uint256 ethDeposited = msg.value; //Deposit value in WEI
        int256 currentEthUSDPrice = getLatestEthUSDPrice(); //Latest price of ETH in USD with a scale of 1e8

        // uint256 usdValueForEthDeposit = ABDKMath64x64.mulu( //Using ABDKMath64x64 for high precision on calculation
        //     ABDKMath64x64.divu(ethDeposited, 1e10),
        //     uint256(currentEthUSDPrice)
        // );
        // uint128 tokenAllocated = uint128(
        //     ABDKMath64x64.divu((usdValueForEthDeposit * 1e18), tokenPriceUsd)
        // );
        uint256 usdValueForEthDeposit = (ethDeposited * // Convert wei to USD scale
            uint256(currentEthUSDPrice)) / 1e18;

        saleDeposit[msg.sender] = ethDeposited;
        uint256 tokenAllocated = (usdValueForEthDeposit * 1e18) / tokenPriceUsd;
        presaleRaisedAmount += ethDeposited;
        addressToPresaleAmount[msg.sender] += tokenAllocated;

        emit PresaleContribution(msg.sender, msg.value, tokenAllocated);
    }

    /// @notice Allows the owner to pause the presale.
    /// @dev Can only be called by the contract owner.
    function pausePresale() public onlyOwner {
        isPresaleActive = false;
    }

    /// @notice Allows the owner to restart the presale.
    /// @dev Can only be called by the contract owner.
    function restartPresale() public onlyOwner {
        isPresaleActive = true;
    }

    /// @notice Allows the owner to withdraw ERC20 tokens from the contract.
    /// @param _receiver The address to which the tokens are sent.
    /// @param _amount The amount of tokens to withdraw.
    /// @dev Can only be called by the contract owner.
    function withdrawTokens(
        address _receiver,
        uint256 _amount
    ) public onlyOwner {
        require(_amount > 0, "Amount should be > 0");

        _token.transfer(_receiver, _amount);
        emit TokensWithdrawn(_receiver, _amount);
    }

    /// @notice Allows the owner to withdraw the ETH raised during the presale.
    /// @dev Reverts if there are no ETH to withdraw.
    function withdrawDeposit() public onlyOwner {
        if (address(this).balance <= 0) revert BEM__ZeroEtherToWithdraw();
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    /**
     * Gets the latest ETH/USD value using Chainlink's pricefeeds...
     */
    function getLatestEthUSDPrice() public view returns (int) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    //AirDrop
    function claimAirdrop(
        bytes32[] calldata merkleProof,
        address user,
        uint256 _tokenAmount
    ) public onlyOwner {
        if (address(user) == address(0)) revert BM__InvalidAddress();
        if (_tokenAmount <= 0) revert BM__InvalidAmount();

        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(user, _tokenAmount)))
        );
        _token.approve(address(this), _tokenAmount);
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf))
            revert BM_InvalidMerkleProof();

        if (!_token.transferFrom(address(this), user, _tokenAmount))
            revert BM__AirDropFailed();

        emit AirDrop(address(this), user, _tokenAmount);
    }
}
/**
 * constructor(
        uint256 
        uint256 
        uint256 
        IERC20  
        bytes32 
    )
 */
