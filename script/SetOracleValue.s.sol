// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PredictionContract} from "../src/PredictionContract.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {console} from "forge-std/console.sol";

contract SetOracleValue is Script {
    function run() external {
        string memory predictionAddr = "0x0000000000000000000000000000000000000000";
        require(
            vm.parseAddress(predictionAddr) != address(0),
            "Prediction contract address not set. Please update predictionAddr with deployed contract address."
        );
        address prediction = vm.parseAddress(predictionAddr);
        
        // Connect to prediction contract
        PredictionContract predictionContract = PredictionContract(prediction);
        
        // Parameters
        uint256 roundNumber = 1; // Change this to target round
        
        // Get Pyth update data (this would come from Pyth's API in production)
        // For testing, you can get this from Pyth's documentation or API
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = hex"0000000000000000000000000000000000000000000000000000000000000000"; // Add Pyth price update data here
        
        // Calculate required fee
        uint256 updateFee = IPyth(predictionContract.pyth()).getUpdateFee(priceUpdateData);
        
        vm.startBroadcast();
        try predictionContract.setActualValueFromPyth{value: updateFee}(
            priceUpdateData,
            roundNumber
        ) {
            console.log("Oracle value updated for round:", roundNumber);
            console.log("Update fee paid:", updateFee);
        } catch Error(string memory reason) {
            console.log("Failed to update oracle value:", reason);
        }
        vm.stopBroadcast();

    }
}
