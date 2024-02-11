// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BemPresale.sol"; // Adjust the path according to your project structure
import "../src/Bem.sol";
import "forge-std/console.sol";
import "foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";

contract BemPresaleTest is Test {
    AggregatorV3Interface priceFeed;
    BemPresale bemPresale;
    BemToken bemToken;
    IERC20 token; // Mock token interface
    address deployer;
    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);
    bytes32 merkleRoot =
        0x36416b1193470bad5c79351fd0ba84f08538c1aff1c2927711494575d2fb5195; // Example merkle root, adjust as needed

    uint256 public constant tokenPriceUsd = 0.0075 * 1e18; //$0.0075

    //Events
    event PresaleContribution(
        address indexed contributor,
        uint256 amount,
        uint256 tokensAllocated
    );

    function setUp() public {
        deployer = address(this);
        // Deploy your token contract and BemPresale contract here
        // Assuming you have a mock token contract or you can deploy a real one for testing
        // token = new MockToken();
        // console.log("TestContractAddress:", address(this));
        bemToken = new BemToken();
        bemToken.initialMint(1000000000);
        bemPresale = new BemPresale(
            10 ether, // presaleCap
            0.01 ether, // presaleMinPurchase
            0.11 ether, // presaleMaxPurchase
            IERC20(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f), // tokenAddress
            merkleRoot
        );
        vm.startPrank(address(bemToken));
        bemToken.approve(address(this), 1000000);
        vm.stopPrank();
        bemToken.externalTransfer(address(bemPresale), 1000000);
        bemPresale.restartPresale();
        // Additional setup like funding the contract with tokens for airdrop, etc.
    }

    function testContributeToPresale() public {
        // Activate presale
        // vm.prank(deployer);
        // bemPresale.restartPresale();

        int256 ethUSD = chainlinkPriceFeed();
        uint256 usdValueForEthDeposit = ABDKMath64x64.mulu( //Using ABDKMath64x64 for high precision on calculation
            ABDKMath64x64.divu(100000000000000000, 1e10),
            uint256(ethUSD)
        );
        uint128 tokenAllocated = uint128(
            ABDKMath64x64.divu((usdValueForEthDeposit * 1e18), tokenPriceUsd)
        );

        // Simulate sending ETH to the presale
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        vm.expectEmit(true, true, true, true);
        emit PresaleContribution(user1, 0.1 ether, tokenAllocated);
        bemPresale.contributeToPresale{value: 100000000000000000}();

        // Check user's presale amount and raised amount
        assertEq(bemPresale.addressToPresaleAmount(user1), tokenAllocated);
        assertEq(bemPresale.presaleRaisedAmount(), 0.1 ether);
        vm.stopPrank();
    }

    function chainlinkPriceFeed() internal returns (int256) {
        priceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    function testPauseAndRestartPresale() public {
        vm.prank(deployer);
        bemPresale.pausePresale();
        assertFalse(bemPresale.isPresaleActive());

        vm.prank(deployer);
        bemPresale.restartPresale();
        assertTrue(bemPresale.isPresaleActive());
    }

    function testWithdrawTokens() public {
        // Assuming setup includes minting tokens to the BemPresale contract
        uint256 amount = 100 ether;
        vm.expectEmit(true, true, true, true);
        // emit TokensWithdrawn(user1, amount);

        vm.prank(deployer);
        bemPresale.withdrawTokens(user1, amount);

        // Check token balance of user1
        assertEq(token.balanceOf(user1), amount);
    }

    function testClaimAirdrop() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[
            0
        ] = 0xcb3a2b5807d4e9ac71d08c7220682b5945f7e1a5b4424af3c14695bf205131dc;
        uint256 tokenAmount = 100 ether;

        vm.expectEmit(true, true, true, true);
        // emit AirDrop(address(bemPresale), user1, tokenAmount);

        vm.prank(deployer);
        bemPresale.claimAirdrop(merkleProof, user1, tokenAmount);

        assertEq(token.balanceOf(user1), tokenAmount);
    }
}
