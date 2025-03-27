// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TypesLib} from "@blocklock-solidity/src/libraries/TypesLib.sol";
import {AbstractBlocklockReceiver} from "@blocklock-solidity/src/AbstractBlocklockReceiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PredictionContract is AbstractBlocklockReceiver, ReentrancyGuard, Ownable {

    struct Round {
        uint256 roundNumber;
        uint256 predictionDeadlineBlock;
        uint256 revealDeadlineBlock;
        uint256 priceReportDeadline;
        uint256 realWorldValue; // real-world value for price ETH/USD from Pyth oracle
        bool resultSet;
    }

    struct Prediction {
        uint256 predictionID;
        uint256 roundNumber;
        address predictor;
        TypesLib.Ciphertext sealedPrediction;
        bytes decryptionKey;
        uint256 revealedValue; // price ETH/USD
        bool revealed;
        uint256 predictionError;
    }

    struct PredictorProfile {
        address predictor;  
        uint256 totalPredictions;
        uint256 cumulativeAbsoluteError;
        uint256 cumulativeSquaredError;
    }

    // ============ Public Storage ============

    uint256 public latestRound = 0;

    IPyth public pyth;
    bytes32 public priceFeedId;

    // support multiple price feeds
    bytes32[] public priceFeedIds;

    mapping(uint256 => mapping(address => uint256)) public roundToPredictorToID; // Mapping of round number to predictor to prediction ID
    mapping(uint256 => Prediction) public predictionsByID;
    mapping(uint256 => Round) public roundByNumber;
    mapping(address => PredictorProfile) public predictorProfiles;

    // ============ Events ===============

    event NewRound(uint256 roundNumber, uint256 predictionDeadlineBlock, uint256 revealDeadlineBlock, uint256 priceReportDeadline);
    event PredictionSubmitted(uint256 indexed id, address indexed predictor);
    event PredictionRevealed(uint256 indexed id, uint256 value, uint256 predictionError);
    event ResultSet(uint256 actualValue);
    event PredictorProfileUpdated(address indexed predictor, uint256 totalPredictions, uint256 cumulativeAbsoluteError, uint256 cumulativeSquaredError);

    // ============ Modifiers ============
    
    modifier onlyBefore(uint256 blockNum) {
        require(block.number < blockNum, "Too late.");
        _;
    }

    modifier onlyAfter(uint256 blockNum) {
        require(block.number >= blockNum, "Too early.");
        _;
    }

    modifier onlyInBlockInterval(uint256 startBlock, uint256 endBlock) {
        require(block.number > startBlock && block.number < endBlock, "Not in price update interval.");
        _;
    }

    // ============ Constructor ============

    constructor(address blocklockContract, address pythContract, bytes32 newPriceFeedId, address initialOwner)
        AbstractBlocklockReceiver(blocklockContract)
        Ownable(initialOwner)
    {
        pyth = IPyth(pythContract);
        priceFeedId = newPriceFeedId;
    }

    // ============ External Functions ============

    // Function for starting a new prediction round
    function startNewRound(uint256 _predictionDeadlineBlock, uint256 _revealDeadlineBlock, uint256 _priceReportInterval)
        external
        onlyOwner
    {
        require(_predictionDeadlineBlock > block.number, "Invalid prediction deadline.");
        require(_revealDeadlineBlock > _predictionDeadlineBlock, "Invalid reveal deadline.");
        require(_revealDeadlineBlock - _priceReportInterval > _predictionDeadlineBlock, "Invalid price report interval.");

        latestRound++;
        Round memory r = Round({
            roundNumber: latestRound,
            predictionDeadlineBlock: _predictionDeadlineBlock,
            revealDeadlineBlock: _revealDeadlineBlock,
            priceReportDeadline: _revealDeadlineBlock - _priceReportInterval, // reveal deadline - some amount of blocks (e.g. 2)
            realWorldValue: 0,
            resultSet: false
        });

        roundByNumber[latestRound] = r;
        emit NewRound(latestRound, _predictionDeadlineBlock, _revealDeadlineBlock, _revealDeadlineBlock - _priceReportInterval);
    }

    // Function for submitting sealed prediction    
    function submitSealedPrediction(TypesLib.Ciphertext calldata sealedPrediction, uint256 _roundNumber)
        external
        onlyBefore(roundByNumber[_roundNumber].predictionDeadlineBlock)
        returns (uint256)
    {
        require(roundToPredictorToID[_roundNumber][msg.sender] == 0, "One prediction per address per round.");
        uint256 id = blocklock.requestBlocklock(roundByNumber[_roundNumber].revealDeadlineBlock, sealedPrediction);

        Prediction memory p = Prediction({
            predictionID: id,
            roundNumber: _roundNumber,
            predictor: msg.sender,
            sealedPrediction: sealedPrediction,
            decryptionKey: hex"",
            revealedValue: 0,
            revealed: false,
            predictionError: 0
        });

        predictionsByID[id] = p;
        roundToPredictorToID[_roundNumber][msg.sender] = id;

        emit PredictionSubmitted(id, msg.sender);
        return id;
    }

    // Function for revealing prediction (Randamu oracle)    
    function receiveBlocklock(uint256 requestID, bytes calldata decryptionKey)
        external
        override
        onlyAfter(roundByNumber[predictionsByID[requestID].roundNumber].revealDeadlineBlock)
        nonReentrant
    {        
        Prediction storage p = predictionsByID[requestID];
        require(roundByNumber[p.roundNumber].resultSet, "Real value not set.");
        require(!p.revealed, "Already revealed.");

        p.decryptionKey = decryptionKey;
        uint256 revealed = abi.decode(blocklock.decrypt(p.sealedPrediction, decryptionKey), (uint256));
        p.revealedValue = revealed;
        p.revealed = true;
        
        
        p.predictionError = _absDiff(revealed, roundByNumber[p.roundNumber].realWorldValue);

        PredictorProfile storage profile = predictorProfiles[p.predictor];
        if (profile.predictor == address(0)) {
            profile.predictor = msg.sender;
        }
        profile.totalPredictions++;
        profile.cumulativeAbsoluteError += p.predictionError;
        profile.cumulativeSquaredError += p.predictionError * p.predictionError;
        emit PredictorProfileUpdated(
            msg.sender, 
            profile.totalPredictions, 
            profile.cumulativeAbsoluteError,
            profile.cumulativeSquaredError
        );
        emit PredictionRevealed(requestID, revealed, p.predictionError);
    }

    // Function for pulling ground truth from real-world oracle (Pyth)
    function setActualValueFromPyth(bytes[] calldata priceUpdateData, uint256 _roundNumber)
        external
        payable
        onlyAfter(roundByNumber[_roundNumber].predictionDeadlineBlock)
        onlyInBlockInterval(roundByNumber[_roundNumber].priceReportDeadline, roundByNumber[_roundNumber].revealDeadlineBlock)
        nonReentrant
    {
        require(!roundByNumber[_roundNumber].resultSet, "Already set.");

        uint256 fee = pyth.getUpdateFee(priceUpdateData);
        require(msg.value >= fee, "Insufficient fee");

        pyth.updatePriceFeeds{value: fee}(priceUpdateData);

        PythStructs.Price memory price = _validateAndGetPrice(
               roundByNumber[_roundNumber].priceReportDeadline
       );
        require(price.price > 0, "Invalid price from oracle");

        // use the properly scaled price value
        uint256 scaledPrice = _parsePythPrice(price);

        roundByNumber[_roundNumber].realWorldValue = scaledPrice;
        roundByNumber[_roundNumber].resultSet = true;

        emit ResultSet(uint256(int256(price.price)));
    }

    // ============ Getter Functions ============   

    function getPrediction(uint256 id)
        external
        view
        returns (address predictor, uint256 value, uint256 score, bool revealed)
    {
        Prediction memory p = predictionsByID[id];
        return (p.predictor, p.revealedValue, p.predictionError, p.revealed);
    }

    // ============ Internal Functions ============

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a - b : b - a;
    }
    //  price validation method
    function _validateAndGetPrice(
        uint256 priceReportDeadline
    ) internal view returns (PythStructs.Price memory) {
        
     
        // Constants for validation
        uint256 MAX_PRICE_AGE = 60;  // 60 seconds
        uint256 MAX_CONFIDENCE_RATIO = 10;  // Confidence < price/10

        // Retrieve price from Pyth
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            priceFeedId, 
            (block.number - priceReportDeadline) * 15  // ~15 seconds per block
        );

        // Validate price components
        require(price.price > 0, "Invalid price value");
        
        // Check price age
        uint256 currentTimestamp = block.timestamp;
        require(
            currentTimestamp - price.publishTime <= MAX_PRICE_AGE, 
            "Price update too old"
        );

        // Check price confidence
        require(
            price.conf < uint64(abs(price.price) / MAX_CONFIDENCE_RATIO), 
            "Price confidence too low"
        );

        return price;
    }

    // price parsing method
    function _parsePythPrice(PythStructs.Price memory price) internal pure returns (uint256) {
        int64 priceValue = price.price;
        int32 expo = price.expo;

        // handle negative price values
        uint256 absPrice = priceValue >= 0 ? uint256(int256(priceValue)) : uint256(-int256(priceValue));
        
        // Convert to standard representation
        if (expo >= 0) {
            return absPrice * (10 ** uint32(expo));
        } else {
            // we can normalize to a fixed precision (e.g. 8 decimals)
            uint32 normalizedPrecision = 8;
            int32 adjustedExpo = -expo;
            if (uint32(adjustedExpo) <= normalizedPrecision) {
                return absPrice * (10 ** (normalizedPrecision - uint32(adjustedExpo)));
            } else {
                return absPrice / (10 ** (uint32(adjustedExpo) - normalizedPrecision));
            }
        }
    }

    // Utility method to handle absolute value for int256
    function abs(int256 x) internal pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}