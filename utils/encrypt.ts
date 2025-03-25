import { ethers, getBytes } from "ethers";
import { Blocklock, SolidityEncoder, encodeCiphertextToSolidity } from "blocklock-js";
import dotenv from "dotenv";

// Load environment variables
dotenv.config();

const BLOCKLOCK_DEFAULT_PUBLIC_KEY = {
    x: {
        c0: BigInt("0x2691d39ecc380bfa873911a0b848c77556ee948fb8ab649137d3d3e78153f6ca"),
        c1: BigInt("0x2863e20a5125b098108a5061b31f405e16a069e9ebff60022f57f4c4fd0237bf"),
    },
    y: {
        c0: BigInt("0x193513dbe180d700b189c529754f650b7b7882122c8a1e242a938d23ea9f765c"),
        c1: BigInt("0x11c939ea560caf31f552c9c4879b15865d38ba1dfb0f7a7d2ac46a4f0cae25ba"),
    },
};

async function submitPrediction(
    privateKey: string,
    contractAddress: string,
    predictionValue: number
) {
    try {
        const provider = new ethers.JsonRpcProvider(process.env.CALIBRATION_TESTNET_RPC_URL);
        const wallet = new ethers.Wallet(privateKey, provider);

        // Connect to the AIRank contract
        const predictionContract = new ethers.Contract(
            contractAddress, 
            require("../out/AIRank.sol/PredictionLeaderboard.json").abi, 
            wallet
        );
        const blocklockjs = new Blocklock(wallet, await predictionContract.blocklock());

        // Get prediction deadline block
        const deadlineBlock = await predictionContract.predictionDeadlineBlock();

        // Encode the prediction value
        const encoder = new SolidityEncoder();
        const msgBytes = encoder.encodeInt256(BigInt(predictionValue));
        const encodedMessage = getBytes(msgBytes);

        // Encrypt the prediction
        const ciphertext = blocklockjs.encrypt(
            encodedMessage, 
            deadlineBlock, 
            BLOCKLOCK_DEFAULT_PUBLIC_KEY
        );

        // Submit the sealed prediction
        const tx = await predictionContract.submitSealedPrediction(
            encodeCiphertextToSolidity(ciphertext)
        );
        const receipt = await tx.wait(1);

        if (!receipt) {
            throw new Error("Transaction has not been mined");
        }

        // Get prediction ID
        const predictor = await wallet.getAddress();
        const predictionID = await predictionContract.predictorToID(predictor);

        console.log(`Prediction submitted successfully! Transaction hash: ${receipt.hash}`);
        console.log(`Prediction ID: ${predictionID}`);
        console.log(`Predictor: ${predictor}`);
    } catch (error) {
        console.error("Error:", (error as Error).message || error);
    }
}

// Main function to execute the script
async function main() {
    const PRIVATE_KEY = process.env.CALIBRATION_TESTNET_PRIVATE_KEY;
    const CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS";
    const PREDICTION_VALUE = 100; // Your prediction value

    // Ensure required values are provided
    if (!PRIVATE_KEY) {
        console.error("PRIVATE_KEY is missing in .env file!");
        process.exit(1);
    }

    // Execute the function
    await submitPrediction(PRIVATE_KEY, CONTRACT_ADDRESS, PREDICTION_VALUE);
}

// Run the script
main().catch((error) => {
    console.error("Error:", (error as Error).message || error);
});