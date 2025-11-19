// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrustAnchorZK.sol";
import "../src/StateCommitmentVerifier.sol";
import "../src/ZKVerifier.sol";

/**
 * @title Deploy Script for Rayls Testnet
 * @notice Deploys TrustAnchorZK with REAL Groth16 verifier to Rayls
 * @dev Usage:
 *   source .env
 *   forge script script/DeployRayls.s.sol:DeployRaylsScript \
 *     --rpc-url $RAYLS_TESTNET_RPC_URL \
 *     --broadcast \
 *     --legacy \
 *     -vvvv
 */
contract DeployRaylsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying to Rayls Testnet ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy REAL Groth16 verifier
        console.log("1. Deploying StateCommitmentGroth16Verifier...");
        StateCommitmentGroth16Verifier groth16Verifier = new StateCommitmentGroth16Verifier();
        console.log("   Address:", address(groth16Verifier));
        console.log("");

        // 2. Deploy ZK Verifier wrapper
        console.log("2. Deploying StateCommitmentVerifier (wrapper)...");
        StateCommitmentVerifier zkVerifier = new StateCommitmentVerifier(address(groth16Verifier));
        console.log("   Address:", address(zkVerifier));
        console.log("");

        // 3. Deploy TrustAnchorZK (deployer is validator for testnet)
        console.log("3. Deploying TrustAnchorZK...");
        TrustAnchorZK trustAnchor = new TrustAnchorZK(
            deployer, // Deployer is validator for testnet
            5,        // 5 blocks minimum interval
            address(zkVerifier)
        );
        console.log("   Address:", address(trustAnchor));
        console.log("   Validator:", deployer);
        console.log("   Min Interval: 5 blocks");
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("=== Deployment Summary ===");
        console.log("Network: Rayls Testnet");
        console.log("Chain ID:", block.chainid);
        console.log("Explorer: https://devnet-explorer.rayls.com");
        console.log("");
        console.log("Contracts:");
        console.log("  Groth16 Verifier:", address(groth16Verifier));
        console.log("  ZK Verifier:", address(zkVerifier));
        console.log("  TrustAnchorZK:", address(trustAnchor));
        console.log("");
        console.log("=== Verification Details ===");
        console.log("Circuit: StateCommitment.circom");
        console.log("Public Inputs: [commitment, blockNumber, minBlockNumber]");
        console.log("Constraints: 365 non-linear");
        console.log("Verification: REAL Groth16 (not mock!)");
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. View contracts on explorer:");
        console.log("   https://devnet-explorer.rayls.com/address/%s", address(trustAnchor));
        console.log("2. Save contract addresses in README.md");
        console.log("3. Generate ZK proofs using:");
        console.log("   snarkjs groth16 fullprove input.json build/StateCommitment.wasm build/circuit_0000.zkey proof.json public.json");
        console.log("4. Submit test commitments via TrustAnchorZK.submitZKCommitment()");
        console.log("");
        console.log("=== Test Submission Example ===");
        console.log("cast send %s \\", address(trustAnchor));
        console.log('  "submitZKCommitment(bytes32,uint256,uint256,bytes32,uint256[8])" \\');
        console.log("  0x21726f818bfde6ef03d4a77fc5ac785b86daafba1c932f553a2cf985a91870da \\");
        console.log("  100 \\");
        console.log("  $(cast block-number --rpc-url https://devnet-rpc.rayls.com) \\");
        console.log("  0x0000000000000000000000000000000000000000000000000000000000000001 \\");
        console.log('  "[17863004283804941110057119528671280031108086509786281072083332953226525840967,10733677236981470644945894584619418706937269997198853777456122904654640572909,2816324332338101265443586691783080741815369230188377221244030971536969439002,17262728235025506396548565903299937527543498924288633046100140555539146137408,16414200452151368744009120127259811270355758774780588963988343136776956456595,13302189960695360732829828302689351600151095226419378048416415821859019644722,11511439461660985645261522804983402206178846344477038625254505692391653877459,11706338943619448564728313747461358949542874959064253233329705162912985588989]" \\');
        console.log("  --rpc-url https://devnet-rpc.rayls.com \\");
        console.log("  --private-key $PRIVATE_KEY");
    }
}
