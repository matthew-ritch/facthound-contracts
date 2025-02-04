// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {FactHound} from "../src/FactHound.sol";

contract FactHoundScript is Script {
    function setUp() public {}

    function run() public {
        address deployerAddress = vm.envAddress("WALLET_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("WALLET_KEY");
        uint16 feePer10000 = 1000;
        vm.startBroadcast(deployerPrivateKey);
        FactHound facthound = new FactHound(deployerAddress, feePer10000);
        vm.stopBroadcast();
    }
}

    

