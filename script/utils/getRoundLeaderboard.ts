import { ethers } from "ethers";
import dotenv from "dotenv";
import * as fs from 'fs';

// Load environment variables
dotenv.config();

// Define Types
interface PointG2 {
  x: [bigint, bigint];
  y: [bigint, bigint];
}

interface Ciphertext {
  u: PointG2;
  v: string;
  w: string;
}

interface PredictionResponse {
  predictor: string;
  value: bigint;
  predictionError: bigint;
  revealed: boolean;
}

interface Round {
  roundNumber: bigint;
  predictionDeadlineBlock: bigint;
  revealDeadlineBlock: bigint;
  priceReportDeadline: bigint;
  realWorldValue: bigint;
  resultSet: boolean;
}

interface Prediction {
  predictionID: bigint;
  roundNumber: bigint;
  predictor: string;
  sealedPrediction: Ciphertext;
  decryptionKey: string;
  revealedValue: bigint;
  revealed: boolean;
  predictionError: bigint;
}

async function getRoundLeaderboard(roundNumber: bigint, contractAddress: string) {
  try {
    const provider = new ethers.JsonRpcProvider(process.env.CALIBRATION_TESTNET_RPC_URL);
    const contract = new ethers.Contract(
      contractAddress, 
      require("../out/PredictionContract.sol/PredictionContract.json").abi,
      provider
    );

    // Get round details
    const round: Round = await contract.roundByNumber(roundNumber);
    
    // Get prediction IDs for this round
    const predictionIDs = await contract.roundToPredictionIDs(roundNumber);
    const predictorProfiles: Prediction[] = [];
    
    // Fetch each prediction by its ID
    for (const id of predictionIDs) {
      const prediction = await contract.predictionsByID(id);
      if (prediction.revealed) {
        predictorProfiles.push(prediction);
      }
    }
    
    // Sort predictions by prediction error (lower is better)
    const sortedPredictions = predictorProfiles.sort((a, b) => 
      Number(a.predictionError - b.predictionError)
    );

    console.log(`\nRound ${roundNumber.toString()} Leaderboard:`);
    console.log("Real World Value:", round.resultSet ? round.realWorldValue.toString() : "Not set");
    console.log("---");
    
    sortedPredictions.forEach((prediction, index) => {
      console.log(`${index + 1}. Address: ${prediction.predictor}`);
      console.log(`   Predicted Value: ${prediction.revealedValue.toString()}`);
      console.log(`   Prediction Error: ${prediction.predictionError.toString()}`);
      console.log("---");
    });

  } catch (error) {
    console.error("Error fetching round predictions:", error);
  }
}

// Main function to handle script execution
async function main() {
  try {
    const contractAddress = fs.readFileSync('./deployments/latest_prediction.txt', 'utf8').trim();
    const roundNumber = BigInt("1"); // Change as needed

    // Fetch all predictions for the round
    await getRoundLeaderboard(roundNumber, contractAddress);
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

// Run the main function
main().catch((error) => console.error("Unhandled error:", error));