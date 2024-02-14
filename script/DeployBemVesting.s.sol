// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console2} from "lib/forge-std/src/Script.sol";
import {BemToken} from "../src/Bem.sol";
import {BemPresale} from "../src/BemPresale.sol";
import {PresaleTokenVesting} from "../src/BemTokenVesting.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBemVesting is Script {
    function run() external returns (PresaleTokenVesting) {
        vm.startBroadcast();
        BemToken bemToken = new BemToken();
        // BemPresale bemPresale = new BemPresale(
        //     10 ether,
        //     0.0005 ether,
        //     0.009 ether,
        //     IERC20(bemToken),
        //     0x3a66ce04bfa0fac12c5b24f150c3b7b16f81a7ddae4778862490612445a7c5ae
        // );
        PresaleTokenVesting bemVesting = new PresaleTokenVesting(
            IERC20(bemToken),
            0x876ae3d088f6a906995a595a1fafcded051dc6ab0aad53df87e9c8543b7a32ee
        );
        vm.stopBroadcast();
        return bemVesting;
    }
}
