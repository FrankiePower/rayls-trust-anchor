# Rayls Trust Anchor - Frontend

A sleek React + Vite frontend for demonstrating REAL zero-knowledge proofs with wallet integration.

## Features

✅ **Wallet Connect** - MetaMask integration with ethers.js v6
✅ **Network Switching** - Auto-add Rayls Testnet & Sepolia
✅ **Live Queries** - Query Ethereum commitments in real-time
✅ **Token Transfers** - Transfer DBOND tokens on Rayls
✅ **Visual Architecture** - See the 3-layer design
✅ **Statistics Dashboard** - Live ZK verification stats
✅ **Direct Explorer Links** - One-click to Etherscan & Rayls Explorer

## Quick Start

```bash
cd frontend
npm install  # Already done!
npm run dev
```

Then open: http://localhost:5173

## Demo Flow

1. **Connect Wallet** - Click "Connect Wallet" button
2. **Transfer Tokens** - Switch to Rayls network, transfer DBOND
3. **Query Commitment** - Check if block 100 commitment exists on Ethereum
4. **Show Results** - Display verified commitment details
5. **Explorer Links** - Click to view on block explorers

## What It Does

- Connects to your MetaMask wallet
- Queries TrustAnchorZK contract on Ethereum Sepolia
- Transfers tokens on Rayls Testnet
- Shows live verification statistics
- Links directly to verified contracts on Etherscan

## Tech Stack

- **React** - UI library
- **Vite** - Build tool (fast!)
- **ethers.js v6** - Ethereum interactions
- **Native CSS** - Custom styling (no Tailwind needed)

## Contract Addresses

**Ethereum Sepolia:**
- TrustAnchorZK: `0xB512c3bf279c8222B55423f0D2375753F76dE2dC`
- Groth16 Verifier: `0x509Cdd429D01C4aB64431A8b4db8735a26f031F2`

**Rayls Testnet:**
- DemoAsset: `0x509Cdd429D01C4aB64431A8b4db8735a26f031F2`
- StateRootCommitter: `0x8a74cCE7275eF27306163210695f3039F820bc17`

## For Judges

This frontend proves the system is real:
1. Connect your own wallet
2. Query commitments - returns real blockchain data
3. Click Etherscan links - see verified contracts
4. Transfer tokens - see transaction on explorer

No backend, no simulation - just real Web3!

---

**Built for Rayls Hackathon with ❤️**
