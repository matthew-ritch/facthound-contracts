// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {FactHound} from "../src/FactHound.sol";

contract FactHoundScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("WALLET_KEY");
        uint16 feePer10000 = 200;
        vm.startBroadcast(deployerPrivateKey);
        new FactHound(feePer10000);
        vm.stopBroadcast();
    }
}
