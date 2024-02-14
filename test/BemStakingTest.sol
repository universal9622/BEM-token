// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Bem.sol";
import "../src/BemStaking.sol";

contract BemStakingTest is Test {
    BemToken bem;
    BemStaking bemStaking;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    uint64 public MIN_DURATION = 3 * 30 days;
    uint64 public MAX_DURATION = 2 * 365 days;
    uint256 initialStake = 5000000000000000000000;

    function setUp() public {
        bem = new BemToken();
        bem.initialMint(1000000000000000000000000000);
        bemStaking = new BemStaking(IERC20(bem), address(this), 10);
        vm.prank(address(bem));
        bem.approve(address(this), 1000000000000000000000000);
        bem.externalTransfer(address(bemStaking), 100000000000000000000000);
        bem.externalTransfer(user1, 10000000000000000000000);
        bem.externalTransfer(user2, 20000000000000000000000);
        vm.prank(user1);
        bem.approve(address(bemStaking), 10000000000000000000000);
        vm.prank(user2);
        bem.approve(address(bemStaking), 20000000000000000000000);

        // console.logBool(bemStaking.isActive);
        console.logBool(bemStaking.isActive());
    }

    function testStakeFunction() public {
        vm.startPrank(user1);
        bemStaking.stake(10000000000000000000000, MIN_DURATION);
        assertEqUint(bemStaking.totalSupply(), 10000000000000000000000);
        vm.stopPrank();

        vm.startPrank(user2);
        bemStaking.stake(10000000000000000000000, MIN_DURATION);
        vm.stopPrank();
    }

    function testStakeInvalidAmount() public {
        bytes4 customError = bytes4(keccak256("BMS__InsufficientStake()"));
        vm.expectRevert(customError);
        vm.prank(user1);
        bemStaking.stake(0, MIN_DURATION);
    }

    function testStakeInvalidDuration() public {
        bytes4 customError = bytes4(keccak256("BMS__InvalidDuration()"));
        vm.expectRevert(customError);
        vm.prank(user1);
        bemStaking.stake(initialStake, 2 days); // Less than MIN_DURATION
    }

    function testWithdrawBeforeDurationEnds() public {
        vm.startPrank(user1);
        bemStaking.stake(initialStake, MAX_DURATION);
        bytes4 customError = bytes4(keccak256("BMS__StakingPeriodNotOver()"));
        vm.expectRevert(customError);
        bemStaking.withdraw();
        vm.stopPrank();
    }

    function testStakingPauseAndRestart() public {
        // Pause staking
        bemStaking.pauseStaking();
        vm.expectRevert(BMS__StakingInactive.selector);
        vm.prank(user1);
        bemStaking.stake(initialStake, MIN_DURATION);

        // Restart staking
        bemStaking.restartStaking();
        vm.prank(user1);
        bemStaking.stake(initialStake, MIN_DURATION); // Should succeed now
    }

    function testStakeAndExit() public {
        vm.prank(user1);
        bemStaking.stake(initialStake, MIN_DURATION);
        uint256 balanceBeforeExit = bem.balanceOf(user1);

        // Fast forward time to after the staking duration
        vm.warp(block.timestamp + MIN_DURATION + 1);

        vm.prank(user1);
        bemStaking.exit();

        uint256 balanceAfterExit = bem.balanceOf(user1);
        assertEq(balanceAfterExit, balanceBeforeExit + initialStake); // User gets their stake back
    }
}
