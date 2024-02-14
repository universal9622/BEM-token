// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console2} from "lib/forge-std/src/Script.sol";
import {BemToken} from "../src/Bem.sol";
import {BemPresale} from "../src/BemPresale.sol";
import {BemStaking} from "../src/BemStaking.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBemStaking is Script {
    function run() external returns (BemStaking) {
        vm.startBroadcast();
        BemToken bemToken = new BemToken();
        BemStaking bemStaking = new BemStaking(IERC20(bemToken), msg.sender);
        vm.stopBroadcast();
        return bemStaking;
    }
}
