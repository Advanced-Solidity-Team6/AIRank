import { ethers } from "ethers";
import dotenv from "dotenv";

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
  score: bigint;
  revealed: boolean;
}

// Function to fetch prediction details
async function getPredictionDetails(predictionID: bigint, contractAddress: string) {
  try {
    // Set up provider
    const provider = new ethers.JsonRpcProvider(process.env.CALIBRATION_TESTNET_RPC_URL);

    // Read ABI from file
    const contractABI = require("../out/AIRank.sol/PredictionLeaderboard.json").abi;

    // Connect to the contract
    const contract = new ethers.Contract(contractAddress, contractABI, provider);
    
    // Call the getPrediction function
    const predictionDetails: PredictionResponse = await contract.getPrediction(predictionID);

    // Log the prediction data
    console.log("Prediction Details:");
    console.log("Predictor Address:", predictionDetails.predictor);
    console.log("Revealed Value:", predictionDetails.value.toString());
    console.log("Accuracy Score:", predictionDetails.score.toString());
    console.log("Revealed:", predictionDetails.revealed);

    // Get the real world value if set
    const resultSet = await contract.resultSet();
    if (resultSet) {
      const realValue = await contract.realWorldValue();
      console.log("Actual Value:", realValue.toString());
    } else {
      console.log("Actual value not yet set");
    }

  } catch (error) {
    console.error("Error fetching prediction details:", error);
  }
}

async function getLeaderboard(contractAddress: string) {
  try {
    const provider = new ethers.JsonRpcProvider(process.env.CALIBRATION_TESTNET_RPC_URL);
    const contract = new ethers.Contract(
      contractAddress, 
      require("../out/AIRank.sol/PredictionLeaderboard.json").abi,
      provider
    );

    const leaderboard = await contract.getLeaderboard();
    
    // Sort predictions by score (lower is better)
    const sortedPredictions = leaderboard
      .filter((p: any) => p.revealed)
      .sort((a: any, b: any) => Number(a.accuracyScore - b.accuracyScore));

    console.log("\nLeaderboard:");
    sortedPredictions.forEach((prediction: any, index: number) => {
      console.log(`${index + 1}. Address: ${prediction.predictor}`);
      console.log(`   Value: ${prediction.revealedValue.toString()}`);
      console.log(`   Score: ${prediction.accuracyScore.toString()}`);
      console.log("---");
    });

  } catch (error) {
    console.error("Error fetching leaderboard:", error);
  }
}

// Main function to handle script execution
async function main() {
  // Define prediction ID and contract address
  const predictionId: string = "1"; // Change this as needed
  const contractAddress: string = "YOUR_CONTRACT_ADDRESS"; // Change this as needed

  // Convert prediction ID to BigInt
  const predictionID = BigInt(predictionId);

  // Fetch prediction details
  await getPredictionDetails(predictionID, contractAddress);
  
  // Fetch and display leaderboard
  await getLeaderboard(contractAddress);
}

// Run the main function
main().catch((error) => console.error("Unhandled error:", error));