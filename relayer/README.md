# Rayls Trust Anchor Relayer

Simple on-demand relayer that bridges Rayls state to Ethereum using ZK proofs.

## What It Does

1. **Generates state commitment** on Rayls (StateRootCommitter)
2. **Creates ZK proof** using snarkjs
3. **Submits to Ethereum** with the proof (TrustAnchorZK)

## Quick Start

```bash
cd relayer
npm install
node index.js
```

Or with a specific block number:
```bash
node index.js 200
```

## Output Example

```
🚀 Rayls Trust Anchor Relayer

==================================================
📦 Target Block Number: 200

👛 Relayer Address: 0x8966...420E

==================================================
STEP 1: Generate State Commitment on Rayls
==================================================

📝 State Root: 0x1234...
📦 Block Number: 200
⏳ Transaction sent: 0xabcd...
✅ State commitment generated on Rayls!
🔗 Explorer: https://devnet-explorer.rayls.com/tx/0xabcd...

==================================================
STEP 2: Generate ZK Proof (snarkjs)
==================================================

📋 Circuit Inputs:
   commitment: 15128514155052998...
   blockNumber: 200
⚙️  Using pre-generated proof...
✅ Proof loaded successfully
📦 Proof formatted for Solidity (8 elements)

==================================================
STEP 3: Submit ZK Commitment to Ethereum
==================================================

📝 Commitment: 0x21726f818bfde6ef...
📦 Rayls Block: 100
⏰ Timestamp: 2025-11-19T16:30:00.000Z
⛽ Estimated Gas: 524289
⏳ Transaction sent: 0xefgh...
   Waiting for confirmation...
✅ ZK Commitment submitted to Ethereum!
⛽ Gas Used: 506478
🔗 Etherscan: https://sepolia.etherscan.io/tx/0xefgh...

==================================================
STEP 4: Verify Result
==================================================

📊 Verification Stats:
   Total Commitments: 2
   Transparent: 0
   ZK Verified: 2
   ZK Mode Enabled: Yes

✅ Block 100 has ZK commitment: true

==================================================
🎉 RELAY COMPLETE!
==================================================

The state from Rayls has been anchored to Ethereum
with zero-knowledge proof verification.
```

## For Demo

1. Run the relayer: `node index.js`
2. Show judges the console output
3. Click the explorer links to verify transactions
4. Query the commitment on Etherscan

## Dependencies

- ethers.js v6 - Blockchain interactions
- snarkjs - ZK proof handling
- dotenv - Environment variables

## Notes

- Uses pre-generated proof (for block 100)
- Production would regenerate proof for each block
- Requires PRIVATE_KEY in ../.env

## Production Enhancements

For production, you would add:
- Watch mode to monitor Rayls blocks
- Automatic proof regeneration
- Batching multiple blocks
- Error recovery and retry logic
- Redis queue for async processing

---

Built for Rayls Hackathon
