// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {BLS} from "@blocklock-solidity/src/libraries/BLS.sol";

import {PredictionContract} from "../src/PredictionContract.sol";
import {TypesLib} from "@blocklock-solidity/src/libraries/TypesLib.sol";

contract PredictionContractTest is Test {
    PredictionContract leaderboard;

    function setUp() public {
        leaderboard = new PredictionContract(block.number + 100, address(0));
    }

    function test_userCanOnlySendOnePrediction() public {
        // TODO: mock or generate properly
        uint256 xx = 1;
        uint256 xy = 2;
        uint256 yx = 3;
        uint256 yy = 4;

        TypesLib.Ciphertext memory sealedPrediction =
            TypesLib.Ciphertext({u: BLS.PointG2([xx, xy], [yx, yy]), v: hex"", w: hex""});

        // TODO:
        leaderboard.submitSealedPrediction(sealedPrediction);

        vm.expectRevert();
        leaderboard.submitSealedPrediction(sealedPrediction);
    }

    function test_userCanSendPrediction() public {
        // leaderboard.submitSealedPrediction(hex"");

        // TODO: test the prediction is sent correctly
        // leaderboard.getPrediction(1);
    }

    function test_cantSendPredictionAfterDeadlineBlock() public {
        // leaderboard.submitSealedPrediction(hex"");

        // TODO: test the revert
    }

    function test_cantSendPredictionBeforeDeadlineBlock() public {
        // TODO: test the revert
    }

    function test_revealPrediction() public {
        // leaderboard.submitSealedPrediction(hex"");

        // TODO: test the prediction is revealed correctly
    }
}
