//SPDX-Licese-Identifier:MIT

pragma solidity ^0.8.19;
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/Bem.sol";
import "../src/BemStaking.sol";

contract BemStakingTest is Test {
    BemToken bem;
    BemStaking bemStaking;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint64 public MIN_DURATION = 3 * 30 days;
    uint64 public MAX_DURATION = 2 * 365 days;

    function setUp() public {
        bem = new BemToken();
        bem.initialMint(1000000000000000000000000000);
        bemStaking = new BemStaking(IERC20(bem), address(this));
        vm.prank(address(bem));
        bem.approve(address(this), 1000000000000000000000000);
        bem.externalTransfer(address(bemStaking), 100000000000000000000000);
        bem.externalTransfer(user1, 10000000000000000000000);
        bem.externalTransfer(user2, 20000000000000000000000);

        // console.logBool(bemStaking.isActive);
        console.logBool(bemStaking.isActive());
    }

    function testStakeFunction() public {
        vm.startPrank(user1);
        bemStaking.stake(10000000000000000000000, MIN_DURATION);
        uint256 initialStake = 10000000000000000000000;
        assertEqUint(bemStaking.totalSupply(), initialStake);
        vm.stopPrank();
    }
}
