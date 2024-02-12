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
        0x87ce2f91d80a9f8d74ccd0fa98d6e3bef62f30ac56afb35ba6a2ace6e178b6d5;
    bytes32 adMerkleRoot;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        bemToken = new BemToken();
        bemPresale = new BemPresale(
            100000,
            0.0009 ether,
            0.01 ether,
            IERC20(bemToken),
            adMerkleRoot
        );
        bemVesting = new PresaleTokenVesting(IERC20(bemToken), merkleRoot);
        bemToken.initialMint(1000000000);
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
        ] = 0x8284f03c5cb4d61783fbc3da58bc33c214a27a437381790fd04eb1013929ddf8;
        bemVesting.setVesting(user1, 2996899658660000000000, merkleProof);
    }
}
