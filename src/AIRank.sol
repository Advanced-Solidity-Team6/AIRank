// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TypesLib} from "@blocklock-solidity/src/libraries/TypesLib.sol";
import {AbstractBlocklockReceiver} from "@blocklock-solidity/src/AbstractBlocklockReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WeatherPredictionLeaderboard is AbstractBlocklockReceiver, ReentrancyGuard {
    struct Prediction {
        uint256 predictionID;
        address predictor;
        TypesLib.Ciphertext sealedPrediction;
        bytes decryptionKey;
        int256 revealedValue; // e.g., temperature
        bool revealed;
        uint256 accuracyScore; // lower = better
    }

    uint256 public immutable predictionDeadlineBlock;
    uint256 public realWorldValue; // e.g., 24h later actual temperature
    bool public resultSet;
    uint256 public totalPredictions;
    uint256 public revealedCount;

    mapping(address => uint256) public predictorToID;
    mapping(uint256 => Prediction) public predictionsByID;

    event PredictionSubmitted(uint256 indexed id, address indexed predictor);
    event PredictionRevealed(uint256 indexed id, int256 value, uint256 score);
    event ResultSet(int256 actualValue);

    modifier onlyBefore(uint256 blockNum) {
        require(block.number < blockNum, "Too late.");
        _;
    }

    modifier onlyAfter(uint256 blockNum) {
        require(block.number > blockNum, "Too early.");
        _;
    }

    constructor(uint256 _predictionDeadlineBlock, address blocklockContract)
        AbstractBlocklockReceiver(blocklockContract)
    {
        predictionDeadlineBlock = _predictionDeadlineBlock;
    }

    function submitSealedPrediction(TypesLib.Ciphertext calldata sealedPrediction)
        external
        onlyBefore(predictionDeadlineBlock)
        returns (uint256)
    {
        require(predictorToID[msg.sender] == 0, "One prediction per address.");
        uint256 id = blocklock.requestBlocklock(predictionDeadlineBlock, sealedPrediction);

        Prediction memory p = Prediction({
            predictionID: id,
            predictor: msg.sender,
            sealedPrediction: sealedPrediction,
            decryptionKey: hex"",
            revealedValue: 0,
            revealed: false,
            accuracyScore: 0
        });

        predictionsByID[id] = p;
        predictorToID[msg.sender] = id;
        totalPredictions += 1;

        emit PredictionSubmitted(id, msg.sender);
        return id;
    }

    function setActualValue(int256 _actualValue) external onlyAfter(predictionDeadlineBlock) {
        require(!resultSet, "Already set.");
        realWorldValue = uint256(int256(_actualValue));
        resultSet = true;
        emit ResultSet(_actualValue);
    }

    function receiveBlocklock(uint256 requestID, bytes calldata decryptionKey)
        external
        override
        onlyAfter(predictionDeadlineBlock)
    {
        require(resultSet, "Real value not set yet.");
        Prediction storage p = predictionsByID[requestID];
        require(!p.revealed, "Already revealed.");

        p.decryptionKey = decryptionKey;
        int256 revealed = abi.decode(blocklock.decrypt(p.sealedPrediction, decryptionKey), (int256));
        p.revealedValue = revealed;
        p.revealed = true;
        p.accuracyScore = absDiff(revealed, int256(realWorldValue));
        revealedCount += 1;

        emit PredictionRevealed(requestID, revealed, p.accuracyScore);
    }

    function absDiff(int256 a, int256 b) internal pure returns (uint256) {
        return a >= b ? uint256(a - b) : uint256(b - a);
    }

    function getPrediction(uint256 id)
        external
        view
        returns (address predictor, int256 value, uint256 score, bool revealed)
    {
        Prediction memory p = predictionsByID[id];
        return (p.predictor, p.revealedValue, p.accuracyScore, p.revealed);
    }

    function getLeaderboard() external view returns (Prediction[] memory leaderboard) {
        leaderboard = new Prediction[](totalPredictions);
        uint256 index = 0;

        for (uint256 i = 1; i <= totalPredictions; i++) {
            leaderboard[index++] = predictionsByID[i];
        }

        // NOTE: Sorting by score (ascending) would be done off-chain for now
    }
}
