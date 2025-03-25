// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TypesLib} from "@blocklock-solidity/src/libraries/TypesLib.sol";
import {AbstractBlocklockReceiver} from "@blocklock-solidity/src/AbstractBlocklockReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PredictionLeaderboard is AbstractBlocklockReceiver, ReentrancyGuard, Ownable {
    struct Prediction {
        uint256 predictionID;
        address predictor;
        TypesLib.Ciphertext sealedPrediction;
        bytes decryptionKey;
        int256 revealedValue; // e.g., temperature
        bool revealed;
        uint256 accuracyScore; // lower = better
        uint256 submissionTimestamp;
    }
    // tracking historical predictions (performance)
    struct PredictorProfile {
        address predictor;  
        uint256 totalPredictions;
        uint256 successfulPredictions;
        uint256 cumulativeAccuracyScore;
        uint256 reputationScore;
        uint8 predictionTier;
    }

    // ============ Public Storage ============

    uint256 public immutable predictionDeadlineBlock;
    uint256 public realWorldValue; // e.g., 24h later actual temperature
    bool public resultSet;
    uint256 public totalPredictions;
    uint256 public revealedCount;
    uint256 public constant ACCURACY_THRESHOLD = 2;  // Within ±2°C


    IPyth public pyth;
    bytes32 public priceFeedId;

    mapping(address => uint256) public predictorToID;
    mapping(uint256 => Prediction) public predictionsByID;
    mapping(address => PredictorProfile) public predictorProfiles;

    // ============ Events ===============

    event PredictorProfileUpdated(address indexed predictor, uint256 totalPredictions, uint256 successfulPredictions, uint256 cumulativeAccuracyScore);
    event PredictionSubmitted(uint256 indexed id, address indexed predictor);
    event PredictionRevealed(uint256 indexed id, int256 value, uint256 score);
    event ResultSet(int256 actualValue);

    // ============ Modifiers ============

    modifier onlyBefore(uint256 blockNum) {
        require(block.number < blockNum, "Too late.");
        _;
    }

    modifier onlyAfter(uint256 blockNum) {
        require(block.number > blockNum, "Too early.");
        _;
    }

    // ============ Constructor ============

    constructor(uint256 _predictionDeadlineBlock, address blocklockContract, address pythContract, bytes32 _priceFeedId, address initialOwner)
        AbstractBlocklockReceiver(blocklockContract)
        Ownable(initialOwner)
    {
        predictionDeadlineBlock = _predictionDeadlineBlock;
        pyth = IPyth(pythContract);
        priceFeedId = _priceFeedId;
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
            accuracyScore: 0,
            submissionTimestamp: block.timestamp
        });

        predictionsByID[id] = p;
        predictorToID[msg.sender] = id;
        totalPredictions += 1;

        PredictorProfile memory profile = predictorProfiles[msg.sender];
        profile.predictor = msg.sender;
        profile.totalPredictions++;
        emit PredictorProfileUpdated(
            msg.sender, 
            profile.totalPredictions, 
            profile.successfulPredictions,
            profile.cumulativeAccuracyScore
        );

        emit PredictionSubmitted(id, msg.sender);
        return id;
    }


    function setActualValueFromPyth(bytes[] calldata priceUpdateData)
        external
        payable
        onlyAfter(predictionDeadlineBlock)
    {
        require(!resultSet, "Already set.");

        uint256 fee = pyth.getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Insufficient fee");

        pyth.updatePriceFeeds{value: fee}(priceUpdateData);

        PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeedId, 60);
        require(price.price > 0, "Invalid price from oracle");

        realWorldValue = uint256(int256(price.price)); // note: price has exponent
        resultSet = true;

        emit ResultSet(int256(realWorldValue));
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
        p.accuracyScore = _absDiff(revealed, int256(realWorldValue));
        revealedCount += 1;

        // reputation calculation
        PredictorProfile storage profile = predictorProfiles[p.predictor];
        profile.totalPredictions++;

        // update successful predictions and cumulative accuracy score
        if (p.accuracyScore < ACCURACY_THRESHOLD) {
            profile.successfulPredictions++;
            profile.cumulativeAccuracyScore += p.accuracyScore;
            profile.reputationScore++;

            // calculate prediction tier
            profile.predictionTier = calculateTier(profile.reputationScore);
        }


        emit PredictionRevealed(requestID, revealed, p.accuracyScore);
    }

    // ============ Getter Functions ============

    function calculateTier(uint256 reputationScore) internal pure returns (uint8) {
        if (reputationScore >= 200) {
            return 3; // top tier Master
        } else if (reputationScore >= 100) {
            return 2; // mid tier Expert
        } else if (reputationScore >= 50) {
            return 1; // low tier Novice
        } 
            return 0; // no tier
        }

    function getPredictorProfile(address predictor) 
        external 
        view 
        returns (
            address profileAddress,
            uint256 successfulPredictions, 
            uint256 cumulativeAccuracyScore
        )  
    {  
        PredictorProfile memory profile = predictorProfiles[predictor];
        uint256 avgScore = profile.totalPredictions > 0 
            ? profile.cumulativeAccuracyScore / profile.totalPredictions 
            : 0;
        return (
            profile.predictor, 
            profile.successfulPredictions, 
                vgScore
        );
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

    // ============ Internal Functions ============

    function _absDiff(int256 a, int256 b) internal pure returns (uint256) {
        return a >= b ? uint256(a - b) : uint256(b - a);
    }
}
