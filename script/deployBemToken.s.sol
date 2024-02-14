// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console2} from "lib/forge-std/src/Script.sol";
import {BemToken} from "../src/Bem.sol";

contract DeployBemToken is Script {
    function run() external returns (BemToken) {
        vm.startBroadcast();
        BemToken bemToken = new BemToken();
        vm.stopBroadcast();
        return bemToken;
    }
}
