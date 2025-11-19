// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrustAnchorZK.sol";
import "../src/StateCommitmentVerifier.sol";
import "../src/ZKVerifier.sol";

/**
 * @title Deploy Ethereum Side (Security Layer)
 * @notice Deploys contracts that run ON Ethereum to verify and store commitments
 * @dev Usage:
 *   source .env
 *   forge script script/DeployEthereumSide.s.sol:DeployEthereumSideScript \
 *     --rpc-url $ETHEREUM_SEPOLIA_RPC_URL \
 *     --broadcast \
 *     --verify \
 *     -vvvv
 */
contract DeployEthereumSideScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying to Ethereum Sepolia (Security Layer) ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy REAL Groth16 verifier
        console.log("1. Deploying StateCommitmentGroth16Verifier (REAL ZK)...");
        StateCommitmentGroth16Verifier groth16Verifier = new StateCommitmentGroth16Verifier();
        console.log("   Address:", address(groth16Verifier));
        console.log("   Type: REAL Groth16 (210 lines of cryptography)");
        console.log("   Circuit: StateCommitment.circom (365 constraints)");
        console.log("");

        // 2. Deploy ZK Verifier wrapper
        console.log("2. Deploying StateCommitmentVerifier (wrapper)...");
        StateCommitmentVerifier zkVerifier = new StateCommitmentVerifier(address(groth16Verifier));
        console.log("   Address:", address(zkVerifier));
        console.log("   Wraps: Groth16Verifier");
        console.log("");

        // 3. Deploy TrustAnchorZK (main contract)
        console.log("3. Deploying TrustAnchorZK (main contract)...");
        TrustAnchorZK trustAnchor = new TrustAnchorZK(
            deployer,           // Deployer is validator for testnet
            5,                  // 5 blocks minimum interval
            address(zkVerifier)
        );
        console.log("   Address:", address(trustAnchor));
        console.log("   Validator:", deployer);
        console.log("   Min Interval: 5 blocks");
        console.log("   ZK Mode: Enabled");
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("=== Ethereum Side Deployment Complete ===");
        console.log("");
        console.log("Contracts on Ethereum Sepolia:");
        console.log("  Groth16 Verifier:", address(groth16Verifier));
        console.log("  ZK Verifier:", address(zkVerifier));
        console.log("  TrustAnchorZK:", address(trustAnchor));
        console.log("");
        console.log("Explorer:");
        console.log("  https://sepolia.etherscan.io/address/%s", address(trustAnchor));
        console.log("");
        console.log("=== Complete Architecture ===");
        console.log("");
        console.log("Rayls Testnet (L1):");
        console.log("  - StateRootCommitter (generates commitments)");
        console.log("  - DemoAsset (tokenized assets)");
        console.log("");
        console.log("Ethereum Sepolia (Security Layer):");
        console.log("  - TrustAnchorZK (stores commitments)");
        console.log("  - ZK Verifiers (verify proofs)");
        console.log("");
        console.log("=== How to Use ===");
        console.log("");
        console.log("1. On Rayls: Generate state commitment");
        console.log("   cast send <COMMITTER_ADDRESS> \\");
        console.log('     "generateStateRoot(bytes32,uint256)" \\');
        console.log("     <STATE_ROOT> <BLOCK_NUMBER>");
        console.log("");
        console.log("2. Off-chain: Generate ZK proof");
        console.log("   snarkjs groth16 fullprove input.json build/StateCommitment.wasm build/circuit_0000.zkey proof.json public.json");
        console.log("");
        console.log("3. On Ethereum: Submit commitment with proof");
        console.log("   cast send %s \\", address(trustAnchor));
        console.log('     "submitZKCommitment(bytes32,uint256,uint256,bytes32,uint256[8])" \\');
        console.log("     <COMMITMENT> <BLOCK_NUM> <TIMESTAMP> <TX_HASH> [proof]");
        console.log("");
        console.log("This creates a trust anchor from Rayls to Ethereum!");
    }
}
