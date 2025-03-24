// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {WeatherPredictionLeaderboard} from "./AIRank.sol";

contract PredictionRoundFactory {
    // Track created prediction rounds
    mapping(uint256 => address) public predictionRounds;
    uint256 public totalRounds;

    // Create a new prediction round
    function createPredictionRound(
        uint256 submissionDeadline,
        address blocklockContract
    ) external returns (address) {
        // Deploy new WeatherPredictionLeaderboard
        WeatherPredictionLeaderboard newRound = new WeatherPredictionLeaderboard(
            submissionDeadline,
            blocklockContract,
            msg.sender
        );

        // Store and track the round
        predictionRounds[totalRounds] = address(newRound);
        totalRounds++;

        return address(newRound);
    }

    // Get all prediction rounds
    function getAllPredictionRounds() external view returns (address[] memory) {
        address[] memory rounds = new address[](totalRounds);
        for (uint256 i = 0; i < totalRounds; i++) {
            rounds[i] = predictionRounds[i];
        }
        return rounds;
    }
}

