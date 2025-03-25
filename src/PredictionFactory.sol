// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {PredictionContract} from "./PredictionContract.sol";

contract PredictionFactory {

    mapping(uint256 => address) public predictionContracts;
    uint256 public totalContracts;

    // Create a new prediction round
    function createPredictionContract(
        address blocklockContract,
        address pythContract,
        bytes32 priceFeedId
    ) external returns (address) {
        // Deploy new PredictionContract
        PredictionContract newContract = new PredictionContract(
            blocklockContract,
            pythContract,
            priceFeedId,
            msg.sender
        );

        // Store and track the round
        predictionContracts[totalContracts] = address(newContract);
        totalContracts++;

        return address(newContract);
    }

    // Get all prediction rounds
    function getAllPredictionContracts() external view returns (address[] memory) {
        address[] memory contracts = new address[](totalContracts);
        for (uint256 i = 0; i < totalContracts; i++) {
            contracts[i] = predictionContracts[i];
        }
        return contracts;
    }
}

