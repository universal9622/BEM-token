//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";

//contract
import "../src/Bem.sol";
import "../src/BemPresale.sol";
import "../src/BemTokenVesting.sol";

contract BemVestingTest is Test {
    BemToken bemToken;
    BemPresale bemPresale;
    PresaleTokenVesting bemVesting;
    bytes32 merkleRoot =
        0x876ae3d088f6a906995a595a1fafcded051dc6ab0aad53df87e9c8543b7a32ee;
    bytes32 adMerkleRoot;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        bemToken = new BemToken();
        bemPresale = new BemPresale(
            100000000000000000000000,
            0.0009 ether,
            0.01 ether,
            IERC20(bemToken),
            adMerkleRoot
        );
        bemVesting = new PresaleTokenVesting(IERC20(bemToken), merkleRoot);
        bemToken.initialMint(1000000000000000000000000000);
        vm.prank(address(bemToken));
        bemToken.approve(address(this), 100000000000000000000000);
        bemToken.externalTransfer(
            address(bemVesting),
            100000000000000000000000
        );
    }

    function testSetVesting() public {
        vm.startPrank(user1);
        vm.deal(user1, 0.1 ether);
        console.log(user1);
        console.log(user2);
        bemPresale.contributeToPresale{value: 0.009 ether}();
        vm.stopPrank();
        vm.startPrank(user2);
        vm.deal(user2, 0.1 ether);
        bemPresale.contributeToPresale{value: 0.008 ether}();
        vm.stopPrank();
        console.log(
            "Token allocated:",
            bemPresale.addressToPresaleAmount(user1)
        );
        console.log(
            "Token allocated:",
            bemPresale.addressToPresaleAmount(user2)
        );
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[
            0
        ] = 0xbad12c8c8d6226f8b2324bc24953621a73dfe253c242977347ec916119b0408c; //Use Openzeppelin's js library for MerkleRoot and MerkleProof generation...
        bemVesting.setVesting(user1, 2996899658660000000000, merkleProof);
        bytes32 vestingScheduleId = bemVesting
            .computeVestingScheduleIdForHolder(user1);
        assertEq(
            bemVesting.getVestingInfo(vestingScheduleId).beneficiary,
            user1
        );
        // console.log(bemVesting.getVestingInfo(vestingScheduleId).beneficiary);
        // console.log(bemVesting.getVestingInfo(vestingScheduleId).totalAmount);
        // console.logBytes32(vestingScheduleId);
    }

    function testVestingRelease() public {
        testSetVesting();
        bytes32 vestingScheduleId = 0x344fe5fd3c8a7c63c8c87eb3fc6b39c1a96ced3e956d3a9c234f0133d3fe6c80;
        vm.warp(block.timestamp + (185 * 1 days));
        // console.log(address(this));
        vm.startPrank(user1);
        // console.log(user1);
        // console.log(msg.sender);
        //749.224914665
        //749.224914665
        bemVesting.release(vestingScheduleId);
        console.log("firstUnlock:", IERC20(bemToken).balanceOf(user1));
        uint256 firstUnlockAmount = 749224914665000000000;
        console.logBool(IERC20(bemToken).balanceOf(user1) == firstUnlockAmount);
        // assertEq(uint(IERC20(bemToken).balanceOf(user1)), firstUnlockAmount);
        vm.stopPrank();
    }
}
