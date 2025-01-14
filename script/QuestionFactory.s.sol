// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Question} from "../src/Question.sol";
import {QuestionFactory} from "../src/QuestionFactory.sol";

contract QuestionFactoryScript is Script {
    function setUp() public {}

    function run() public {
        address deployerAddress = vm.envAddress("WALLET_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("WALLET_KEY");
        uint16 feePer10000 = 500;
        vm.startBroadcast(deployerPrivateKey);
        QuestionFactory questionfactory = new QuestionFactory(deployerAddress, feePer10000);
        vm.stopBroadcast();
    }
}

    

