// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/StateRootCommitter.sol";
import "../src/DemoAsset.sol";

/**
 * @title Deploy Rayls Side (L1)
 * @notice Deploys contracts that run ON Rayls to generate commitments
 * @dev Usage:
 *   source .env
 *   forge script script/DeployRaylsSide.s.sol:DeployRaylsSideScript \
 *     --rpc-url $RAYLS_TESTNET_RPC_URL \
 *     --broadcast \
 *     --legacy \
 *     -vvvv
 */
contract DeployRaylsSideScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying to Rayls Testnet (L1 Side) ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy DemoAsset (tokenized RWA on Rayls)
        console.log("1. Deploying DemoAsset (tokenized bond)...");
        DemoAsset demoAsset = new DemoAsset(
            "Demo Treasury Bond",
            "DBOND",
            1000000 * 10**18 // 1M tokens
        );
        console.log("   Address:", address(demoAsset));
        console.log("   Name: Demo Treasury Bond");
        console.log("   Symbol: DBOND");
        console.log("   Initial Supply: 1,000,000 DBOND");
        console.log("");

        // 2. Deploy StateRootCommitter (generates Merkle roots)
        console.log("2. Deploying StateRootCommitter...");
        StateRootCommitter committer = new StateRootCommitter(
            deployer,  // Initial committer (validator)
            10         // Batch every 10 blocks
        );
        console.log("   Address:", address(committer));
        console.log("   Authorized Committer:", deployer);
        console.log("   Batch Interval: 10 blocks");
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("=== Rayls Side Deployment Complete ===");
        console.log("");
        console.log("Contracts on Rayls:");
        console.log("  DemoAsset:", address(demoAsset));
        console.log("  StateRootCommitter:", address(committer));
        console.log("");
        console.log("Explorer:");
        console.log("  https://devnet-explorer.rayls.com/address/%s", address(demoAsset));
        console.log("  https://devnet-explorer.rayls.com/address/%s", address(committer));
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Save these addresses");
        console.log("2. Deploy the Ethereum side (TrustAnchorZK)");
        console.log("3. Generate state commitments:");
        console.log("   cast send %s \\", address(committer));
        console.log('     "generateStateRoot(bytes32,uint256)" \\');
        console.log("     0x<STATE_ROOT> \\");
        console.log("     100 \\");
        console.log("     --rpc-url $RAYLS_TESTNET_RPC_URL \\");
        console.log("     --private-key $PRIVATE_KEY");
    }
}
