// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PredictionFactory} from "../src/PredictionFactory.sol";
import {console} from "forge-std/console.sol";
address constant BLOCKLOCK_CONTRACT = 0xfF66908E1d7d23ff62791505b2eC120128918F44;
address constant PYTH_CONTRACT = 0x0000000000000000000000000000000000000000;
bytes32 constant PYTH_PRICE_FEED_ID = bytes32(0);

contract CreatePredictionContract is Script {
    function run() external {
        string memory factoryAddr = "0x0000000000000000000000000000000000000000";
        require(vm.parseAddress(factoryAddr) != address(0), "Factory address not set. Please update factoryAddr with deployed factory address.");
        address factory = vm.parseAddress(factoryAddr);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        address newContract = PredictionFactory(factory).createPredictionContract(
            BLOCKLOCK_CONTRACT,
            PYTH_CONTRACT,
            PYTH_PRICE_FEED_ID
        );
        vm.stopBroadcast();
        
        // Save new contract address
        string memory deploymentInfo = vm.toString(newContract);
        console.log("Prediction contract deployed at: %s", deploymentInfo);
    }
}