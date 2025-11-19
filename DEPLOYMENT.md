# Deployment Guide

This guide explains how to deploy the Rayls Trust Anchor with **REAL** Groth16 ZK verification to Ethereum.

## Prerequisites

1. **Foundry** installed
2. **Private key** with ETH for gas
3. **RPC URL** for target network
4. **(Optional) Etherscan API key** for contract verification

## Quick Deploy to Sepolia

### 1. Set up environment

```bash
# Copy example env file
cp .env.example .env

# Edit .env and add your private key and RPC URL
# IMPORTANT: Never commit your .env file!
```

### 2. Deploy

```bash
# Deploy to Sepolia testnet
forge script script/Deploy.s.sol:DeploySepoliaScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### 3. Save Contract Addresses

The script will output:
- **Groth16 Verifier**: The real ZK verifier contract
- **ZK Verifier Wrapper**: State commitment verifier
- **TrustAnchorZK**: Main contract for submitting commitments

Save these addresses for your frontend!

## Deploy to Mainnet

**⚠️ WARNING: Use with caution on mainnet!**

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

## Manual Deployment Steps

If you prefer to deploy manually:

```bash
# 1. Deploy Groth16 Verifier
forge create src/StateCommitmentVerifier.sol:StateCommitmentGroth16Verifier \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

# 2. Deploy ZK Verifier Wrapper
forge create src/ZKVerifier.sol:StateCommitmentVerifier \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args <GROTH16_VERIFIER_ADDRESS>

# 3. Deploy TrustAnchorZK
forge create src/TrustAnchorZK.sol:TrustAnchorZK \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --constructor-args <VALIDATOR_ADDRESS> 5 <ZK_VERIFIER_ADDRESS>
```

## After Deployment

### 1. Verify Contracts on Etherscan

The `--verify` flag automatically verifies contracts. To verify manually:

```bash
forge verify-contract <CONTRACT_ADDRESS> \
  src/TrustAnchorZK.sol:TrustAnchorZK \
  --chain sepolia \
  --constructor-args $(cast abi-encode "constructor(address,uint256,address)" <VALIDATOR> 5 <ZK_VERIFIER>)
```

### 2. Authorize Validator

If you need to add additional validators:

```bash
cast send <TRUST_ANCHOR_ADDRESS> \
  "authorizeCommitter(address)" <VALIDATOR_ADDRESS> \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 3. Generate Proofs

Generate ZK proofs for your state commitments:

```bash
# Create input.json with your values
cat > input.json << EOF
{
  "commitment": "15128514155052998246156569550398772363740730525155492237889703652511356317914",
  "blockNumber": "100",
  "minBlockNumber": "0",
  "stateRoot": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
  "validatorId": "1",
  "salt": "12345"
}
EOF

# Generate proof
snarkjs groth16 fullprove \
  input.json \
  build/StateCommitment.wasm \
  build/circuit_0000.zkey \
  proof.json \
  public.json

# Verify proof locally
snarkjs groth16 verify \
  build/verification_key.json \
  public.json \
  proof.json
```

### 4. Submit ZK Commitment

```bash
# Format proof for Solidity (8 uint256 values)
# You can use build/format_proof.js to convert proof.json to Solidity format

cast send <TRUST_ANCHOR_ADDRESS> \
  "submitZKCommitment(bytes32,uint256,uint256,bytes32,uint256[8])" \
  <COMMITMENT> \
  <BLOCK_NUMBER> \
  <TIMESTAMP> \
  <TX_HASH> \
  "[<PROOF_0>,<PROOF_1>,...,<PROOF_7>]" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## Gas Costs

Based on our tests:

- **Deployment**:
  - Groth16 Verifier: ~1,500,000 gas
  - ZK Verifier Wrapper: ~500,000 gas
  - TrustAnchorZK: ~2,000,000 gas
  - **Total**: ~4,000,000 gas (~$20-40 on Sepolia)

- **Operations**:
  - Submit ZK Commitment: ~506,000 gas (~$2-5 on Sepolia)
  - Submit Transparent: ~208,000 gas (~$1-2 on Sepolia)
  - ZK Overhead: ~297,000 gas

## Troubleshooting

### Error: "Invalid proof"

Make sure your proof public signals match what you're submitting:
- public.json should contain: `[commitment, blockNumber, minBlockNumber]`
- These must match the values you pass to `submitZKCommitment()`

### Error: "ZKVerificationFailed"

This means the Groth16 verifier rejected your proof. Check:
1. Proof was generated for the correct circuit
2. Public inputs match (commitment, blockNumber, minBlockNumber)
3. Proof format is correct (8 uint256 values)

### Error: "InvalidBlockNumber"

You're trying to submit a commitment for a block number that's already been submitted or is less than the latest block.

## Security Notes

1. **Never commit your .env file** - it contains your private key!
2. **Use a hardware wallet** for mainnet deployments
3. **Test on testnet first** before deploying to mainnet
4. **Verify contract source** on Etherscan after deployment
5. **Audit your circuit** before production use

## Contract Addresses

After deployment, save your contract addresses here:

### Sepolia Testnet

```
Groth16 Verifier:
ZK Verifier Wrapper:
TrustAnchorZK:
```

### Mainnet

```
Groth16 Verifier:
ZK Verifier Wrapper:
TrustAnchorZK:
```

## Next Steps

After deployment:

1. ✅ Save contract addresses
2. ✅ Verify contracts on Etherscan
3. ✅ Set up frontend with contract addresses
4. ✅ Generate test proofs
5. ✅ Submit test commitments
6. ✅ Monitor gas costs
7. ✅ Set up monitoring/alerts

---

**Questions?** Check the main [README.md](README.md) or open an issue on GitHub.
