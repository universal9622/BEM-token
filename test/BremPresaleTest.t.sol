// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BemPresale.sol"; // Adjust the path according to your project structure
import "../src/Bem.sol";
import "forge-std/console.sol";
import "foundry-chainlink-toolkit/src/interfaces/feeds/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BemPresaleTest is Test {
    AggregatorV3Interface priceFeed;
    BemPresale bemPresale;
    BemToken bemToken;
    IERC20 token; // Mock token interface
    address deployer;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    bytes32 merkleRoot =
        0x3a66ce04bfa0fac12c5b24f150c3b7b16f81a7ddae4778862490612445a7c5ae; // Example merkle root, adjust as needed

    uint256 public constant tokenPriceUsd = 0.0075 * 1e18; //$0.0075

    //Events
    event PresaleContribution(
        address indexed contributor,
        uint256 amount,
        uint256 tokensAllocated
    );
    event TokensWithdrawn(address _receiver, uint256 _amount);
    event AirDrop(address source, address destination, uint256 _amount);

    function setUp() public {
        deployer = address(this);
        // Deploy your token contract and BemPresale contract here
        // Assuming you have a mock token contract or you can deploy a real one for testing
        // token = new MockToken();
        // console.log("TestContractAddress:", address(this));
        bemToken = new BemToken();
        bemToken.initialMint(1000000000000000000000000000);
        token = IERC20(bemToken);
        bemPresale = new BemPresale(
            10 ether, // presaleCap
            0.0009 ether, // presaleMinPurchase
            0.11 ether, // presaleMaxPurchase
            IERC20(0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f), // tokenAddress
            merkleRoot
        );
        console.log("user1:", user1);
        console.log("user2:", user2);
        vm.startPrank(address(bemToken));
        bemToken.approve(address(this), 1000000000000000000000000);
        vm.stopPrank();
        bemToken.externalTransfer(
            address(bemPresale),
            1000000000000000000000000
        );
        bemPresale.restartPresale();
        // Additional setup like funding the contract with tokens for airdrop, etc.
    }

    function testContributeToPresale() public {
        // Activate presale
        // vm.prank(deployer);
        // bemPresale.restartPresale();

        int256 ethUSD = chainlinkPriceFeed();
        // uint256 usdValueForEthDeposit = ABDKMath64x64.mulu( //Using ABDKMath64x64 for high precision on calculation
        //     ABDKMath64x64.divu(1000000000000000, 1e10),
        //     uint256(ethUSD)
        // );
        // uint128 tokenAllocated = uint128(
        //     ABDKMath64x64.divu((usdValueForEthDeposit * 1e18), tokenPriceUsd)
        // );
        uint256 ethDeposited = 0.001 ether;
        uint256 usdValueForEthDeposit = (ethDeposited * uint256(ethUSD)) / 1e18;

        uint256 tokenAllocated = (usdValueForEthDeposit * 1e18) / tokenPriceUsd;

        // Simulate sending ETH to the presale
        vm.startPrank(user1);
        vm.deal(user1, 1 ether);
        vm.expectEmit(true, true, true, true);
        emit PresaleContribution(user1, 0.001 ether, tokenAllocated);
        bemPresale.contributeToPresale{value: 0.001 ether}();

        // Check user's presale amount and raised amount
        assertEq(bemPresale.addressToPresaleAmount(user1), tokenAllocated);
        assertEq(bemPresale.presaleRaisedAmount(), 0.001 ether);
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
        uint256 amount = 1000;
        vm.expectEmit(true, true, true, true);
        emit TokensWithdrawn(user1, amount);
        console.log(
            "TokenBalance:",
            IERC20(bemToken).balanceOf(address(bemPresale))
        );
        vm.prank(deployer);
        bemPresale.withdrawTokens(user1, amount);

        // Check token balance of user1
        assertEq(IERC20(bemToken).balanceOf(user1), amount);
    }

    function testClaimAirdrop() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[
            0
        ] = 0x1259f3ff2f491efceef2086c124e6552f460a90747628bcd93a89753caaa9bc1; //Use Openzeppelin's MerkleTree js library for generation of proofs and root
        uint256 tokenAmount = 1000000000000000000000;
        address airdropClaimee = 0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF;
        console.log(merrkleProof());

        vm.expectEmit(true, true, true, true);
        emit AirDrop(address(bemPresale), user1, tokenAmount);

        vm.prank(deployer);
        // bemToken.approve();
        bemPresale.claimAirdrop(merkleProof, airdropClaimee, tokenAmount);

        assertEq(token.balanceOf(airdropClaimee), tokenAmount);
    }

    function merrkleProof() public view returns (bool) {
        bytes32[] memory merkleProof = new bytes32[](1);

        merkleProof[
            0
        ] = 0x1259f3ff2f491efceef2086c124e6552f460a90747628bcd93a89753caaa9bc1;
        uint256 tokenAmount = 1000000000000000000000;
        address airdropClaimee = 0x29E3b139f4393aDda86303fcdAa35F60Bb7092bF;
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(airdropClaimee, tokenAmount)))
        );
        bool proof = MerkleProof.verify(merkleProof, merkleRoot, leaf);
        return proof;
    }
}
