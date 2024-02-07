// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//Error
error BEM__PresaleInactive();
error BEM__InvalidPurchaseAmount();
error BEM__PresaleCapExceeded();
error BEM__MaxAccumulationLimitExceeded();
error BEM__ZeroEtherToWithdraw();

contract PresaleTokenVesting is Ownable {
    IERC20 private immutable _token;

    uint256 public immutable i_presaleCap;
    uint256 public immutable i_presaleMinPurchase;
    uint256 public immutable i_presaleMaxPurchase;

    bool public isPresaleActive;
    uint256 public presaleRaisedAmount;

    //struct
    struct VestingInfo {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 vestingStart;
    }

    //mapping
    mapping(address => uint256) public saleDeposit;
    mapping(address => uint256) public addressToPresaleAmount;

    //Event
    event PresaleContribution(
        address indexed contributor,
        uint256 amount,
        uint256 tokensAllocated
    );

    constructor(
        uint256 presaleCap,
        uint256 presaleMinPurchase,
        uint256 presaleMaxPurchase,
        IERC20 tokenAddress
    ) Ownable(msg.sender) {
        require(presaleCap > 0, "Invalid presalecap");
        require(presaleMinPurchase > 0, "Invalid pre-sale Min purchase");
        require(presaleMaxPurchase > 0, "Invalid pre-sale Max purchase");
        require(
            address(tokenAddress) != address(0),
            "TokenVesting: token is the zero address"
        );

        i_presaleCap = presaleCap;
        i_presaleMinPurchase = presaleMinPurchase;
        i_presaleMaxPurchase = presaleMaxPurchase;
        _token = tokenAddress;
    }

    function contributeToPresale() public payable {
        if (!isPresaleActive) revert BEM__PresaleInactive();
        if (addressToPresaleAmount[msg.sender] >= i_presaleMaxPurchase)
            revert BEM__MaxAccumulationLimitExceeded();
        if (
            msg.value < i_presaleMinPurchase && msg.value > i_presaleMaxPurchase
        ) revert BEM__InvalidPurchaseAmount();
        if (i_presaleCap == presaleRaisedAmount)
            revert BEM__PresaleCapExceeded();
        saleDeposit[msg.sender] = msg.value;
        presaleRaisedAmount += msg.value;
        uint256 tokenAllocated = msg.value / (0.000001 ether);
        addressToPresaleAmount[msg.sender] += tokenAllocated;

        emit PresaleContribution(msg.sender, msg.value, tokenAllocated);
    }

    function pausePresale() public onlyOwner {
        isPresaleActive = false;
    }

    function withdrawDeposit() private onlyOwner {
        if (address(this).balance <= 0) revert BEM__ZeroEtherToWithdraw();
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}
