// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TrustAnchorZK.sol";
import "../src/StateCommitmentVerifier.sol";
import "../src/ZKVerifier.sol";

/**
 * @title Deploy Script for Rayls Trust Anchor
 * @notice Deploys TrustAnchorZK with REAL Groth16 verifier to Ethereum
 * @dev Usage:
 *   forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
 */
contract DeployScript is Script {
    // Deployment parameters
    address public constant VALIDATOR = address(0); // Set this to your validator address
    uint256 public constant MIN_INTERVAL = 5; // 5 blocks minimum between commitments

    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Rayls Trust Anchor Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
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

        // 3. Deploy TrustAnchorZK
        console.log("3. Deploying TrustAnchorZK...");
        address validatorAddress = VALIDATOR != address(0) ? VALIDATOR : deployer;
        TrustAnchorZK trustAnchor = new TrustAnchorZK(
            validatorAddress,
            MIN_INTERVAL,
            address(zkVerifier)
        );
        console.log("   Address:", address(trustAnchor));
        console.log("   Validator:", validatorAddress);
        console.log("   Min Interval:", MIN_INTERVAL);
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("=== Deployment Summary ===");
        console.log("Groth16 Verifier:", address(groth16Verifier));
        console.log("ZK Verifier Wrapper:", address(zkVerifier));
        console.log("TrustAnchorZK:", address(trustAnchor));
        console.log("");
        console.log("=== Verification Keys ===");
        console.log("Circuit: StateCommitment.circom");
        console.log("Public Inputs: [commitment, blockNumber, minBlockNumber]");
        console.log("Constraints: 365 non-linear");
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Save these contract addresses");
        console.log("2. Authorize validator to submit commitments");
        console.log("3. Generate proofs using:");
        console.log("   snarkjs groth16 fullprove input.json build/StateCommitment.wasm build/circuit_0000.zkey proof.json public.json");
        console.log("4. Submit ZK commitments via TrustAnchorZK.submitZKCommitment()");
    }
}

/**
 * @title Sepolia Deployment Script
 * @notice Deploys to Sepolia testnet with testnet-specific parameters
 */
contract DeploySepoliaScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying to Sepolia Testnet ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        require(block.chainid == 11155111, "Not Sepolia!");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy with testnet parameters
        StateCommitmentGroth16Verifier groth16Verifier = new StateCommitmentGroth16Verifier();
        console.log("Groth16 Verifier:", address(groth16Verifier));

        StateCommitmentVerifier zkVerifier = new StateCommitmentVerifier(address(groth16Verifier));
        console.log("ZK Verifier:", address(zkVerifier));

        // Use deployer as validator for testnet
        TrustAnchorZK trustAnchor = new TrustAnchorZK(
            deployer, // Deployer is validator for testnet
            5,        // 5 blocks minimum
            address(zkVerifier)
        );
        console.log("TrustAnchorZK:", address(trustAnchor));

        vm.stopBroadcast();

        console.log("");
        console.log("=== Testnet Deployment Complete ===");
        console.log("You can now submit test commitments using the deployer address");
        console.log("");
        console.log("Example interaction:");
        console.log("cast send", address(trustAnchor));
        console.log('  "submitZKCommitment(bytes32,uint256,uint256,bytes32,uint256[8])"');
        console.log("  <commitment> <blockNum> <timestamp> <txHash> [proof array]");
    }
}
