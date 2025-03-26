// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PredictionContract} from "../src/PredictionContract.sol";

contract StartNewRound is Script {
    function run() external {
        // Load prediction contract address
        string memory predictionAddr = vm.readFile("./deployments/latest_prediction.txt");
        address prediction = vm.parseAddress(predictionAddr);
        
        uint256 currentBlock = block.number;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        PredictionContract(prediction).startNewRound(
            currentBlock + 100,  // predictionDeadline
            currentBlock + 110,  // revealDeadline
            10                  // priceReportInterval
        );
        vm.stopBroadcast();
    }
}