// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PredictionFactory} from "../src/PredictionFactory.sol";

contract DeployFactory is Script {
    function run() external returns (PredictionFactory) {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        PredictionFactory factory = new PredictionFactory();
        vm.stopBroadcast();
        
        // Save deployment info
        string memory deploymentInfo = vm.toString(address(factory));
        vm.writeFile("./deployments/factory.txt", deploymentInfo);
        
        return factory;
    }
}