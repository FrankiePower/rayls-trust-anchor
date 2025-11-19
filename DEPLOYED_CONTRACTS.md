# Deployed Contracts - Rayls Trust Anchor

**Deployment Date**: November 19, 2025
**Deployer**: `0x8966caCc8E138ed0a03aF3Aa4AEe7B79118C420E`
**Status**: ✅ **LIVE ON TESTNETS**

---

## 🌐 Rayls Testnet (L1 - Asset Layer)

**Network**: Rayls Testnet
**Chain ID**: 123123
**RPC URL**: https://devnet-rpc.rayls.com
**Explorer**: https://devnet-explorer.rayls.com

### Deployed Contracts

| Contract | Address | Purpose | Explorer |
|----------|---------|---------|----------|
| **DemoAsset** | `0x509Cdd429D01C4aB64431A8b4db8735a26f031F2` | ERC20 token representing tokenized Treasury Bond | [View](https://devnet-explorer.rayls.com/address/0x509Cdd429D01C4aB64431A8b4db8735a26f031F2) |
| **StateRootCommitter** | `0x8a74cCE7275eF27306163210695f3039F820bc17` | Generates Merkle state commitments every 10 blocks | [View](https://devnet-explorer.rayls.com/address/0x8a74cCE7275eF27306163210695f3039F820bc17) |

### DemoAsset Details

- **Name**: Demo Treasury Bond
- **Symbol**: DBOND
- **Total Supply**: 1,000,000 DBOND
- **Decimals**: 18
- **Owner**: `0x8966caCc8E138ed0a03aF3Aa4AEe7B79118C420E`

**Functions**:
```solidity
// Mint new tokens (owner only)
function mint(address to, uint256 amount) external onlyOwner

// Burn tokens
function burn(uint256 amount) external

// Transfer tokens
function transfer(address to, uint256 amount) external returns (bool)

// Check balance
function balanceOf(address account) external view returns (uint256)
```

### StateRootCommitter Details

- **Authorized Committer**: `0x8966caCc8E138ed0a03aF3Aa4AEe7B79118C420E`
- **Batch Interval**: 10 blocks
- **Status**: Active

**Functions**:
```solidity
// Generate state root commitment
function generateStateRoot(bytes32 _stateRoot, uint256 _blockNumber) external

// Check if should commit
function shouldCommit(uint256 _blockNumber) public view returns (bool)

// Get commitment by block number
function commitments(uint256 blockNumber) public view returns (Commitment memory)
```

---

## 🔐 Ethereum Sepolia (Security Layer)

**Network**: Ethereum Sepolia
**Chain ID**: 11155111
**RPC URL**: https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk
**Explorer**: https://sepolia.etherscan.io
**Verification**: ✅ All contracts verified on Etherscan

### Deployed Contracts

| Contract | Address | Purpose | Explorer |
|----------|---------|---------|----------|
| **StateCommitmentGroth16Verifier** | `0x509Cdd429D01C4aB64431A8b4db8735a26f031F2` | REAL Groth16 ZK verifier (210 lines) | [View Code](https://sepolia.etherscan.io/address/0x509Cdd429D01C4aB64431A8b4db8735a26f031F2#code) |
| **StateCommitmentVerifier** | `0x8a74cCE7275eF27306163210695f3039F820bc17` | ZK verifier wrapper | [View Code](https://sepolia.etherscan.io/address/0x8a74cCE7275eF27306163210695f3039F820bc17#code) |
| **TrustAnchorZK** | `0xB512c3bf279c8222B55423f0D2375753F76dE2dC` | Main trust anchor contract | [View Code](https://sepolia.etherscan.io/address/0xB512c3bf279c8222B55423f0D2375753F76dE2dC#code) |

### StateCommitmentGroth16Verifier Details

- **Type**: REAL Groth16 verifier (not mock!)
- **Circuit**: StateCommitment.circom
- **Constraints**: 365 non-linear
- **Curve**: alt_bn128
- **Protocol**: groth16

**Public Inputs**: `[commitment, blockNumber, minBlockNumber]`
**Private Inputs**: `[stateRoot, validatorId, salt]`

**Function**:
```solidity
// Verify a Groth16 proof
function verifyProof(
    uint[2] calldata _pA,
    uint[2][2] calldata _pB,
    uint[2] calldata _pC,
    uint[3] calldata _pubSignals
) public view returns (bool)
```

### StateCommitmentVerifier Details

- **Groth16 Verifier**: `0x509Cdd429D01C4aB64431A8b4db8735a26f031F2`
- **Owner**: `0x8966caCc8E138ed0a03aF3Aa4AEe7B79118C420E`

**Functions**:
```solidity
// Verify state commitment with ZK proof
function verifyStateCommitmentView(
    uint[8] calldata _proof,
    bytes32 _commitment,
    uint256 _blockNumber,
    uint256 _minBlockNumber
) external view returns (bool)

// Update Groth16 verifier
function updateGroth16Verifier(address _newVerifier) external onlyOwner
```

### TrustAnchorZK Details

- **Validator**: `0x8966caCc8E138ed0a03aF3Aa4AEe7B79118C420E`
- **Min Interval**: 5 blocks
- **ZK Mode**: ✅ Enabled
- **ZK Verifier**: `0x8a74cCE7275eF27306163210695f3039F820bc17`

**Key Functions**:
```solidity
// Submit ZK commitment (main function!)
function submitZKCommitment(
    bytes32 _commitment,
    uint256 _raylsBlockNumber,
    uint256 _raylsTimestamp,
    bytes32 _raylsTxHash,
    uint[8] calldata _proof
) external onlyAuthorizedSubmitter

// Submit transparent commitment (no ZK)
function submitCommitment(
    bytes32 _stateRoot,
    uint256 _raylsBlockNumber,
    uint256 _raylsTimestamp,
    bytes32 _raylsTxHash
) external onlyAuthorizedSubmitter

// Query ZK commitment
function getZKCommitment(uint256 _raylsBlockNumber)
    external view returns (ZKCommitment memory)

// Check if ZK commitment exists
function hasZKCommitment(uint256 _raylsBlockNumber)
    external view returns (bool)

// Get verification statistics
function getVerificationStats()
    external view returns (uint256[4] memory)
```

---

## 📊 Deployment Statistics

### Gas Costs

**Rayls Testnet**:
- DemoAsset: 1,103,567 gas (~0.044 USDgas)
- StateRootCommitter: 1,147,984 gas (~0.046 USDgas)
- **Total**: 2,251,551 gas (~0.09 USDgas)

**Ethereum Sepolia**:
- Groth16 Verifier: 338,972 gas
- StateCommitmentVerifier: 973,881 gas
- TrustAnchorZK: 2,698,631 gas
- **Total**: 4,011,484 gas (~0.0002 ETH @ 0.05 gwei)

### Test Coverage

- **Total Tests**: 24
- **Pass Rate**: 100% ✅
- **ZK Tests**: 12 (with REAL proofs)
- **Integration Tests**: 12

### Architecture Validation

- ✅ REAL Groth16 cryptography (not mock)
- ✅ Contracts verified on Etherscan
- ✅ Cross-chain architecture
- ✅ Privacy-preserving commitments
- ✅ Backwards compatible (transparent mode)
- ✅ Production-ready code structure

---

## 🔗 Cross-Chain Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  Rayls Testnet (L1)                          │
├─────────────────────────────────────────────────────────────┤
│  1. DemoAsset: Alice transfers 1000 DBOND to Bob            │
│     → State changes                                          │
│                                                              │
│  2. StateRootCommitter: Compute Merkle root                 │
│     → generateStateRoot(root, blockNum)                     │
│     → Event: StateRootGenerated                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    (Off-chain relayer)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Off-Chain (Your Computer)                       │
├─────────────────────────────────────────────────────────────┤
│  3. Generate ZK Proof using snarkjs                         │
│     → Input: {commitment, blockNumber, stateRoot, ...}      │
│     → Output: proof.json (8 uint256 values)                 │
│     → Verified locally: "OK!"                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    (Submit to Ethereum)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│               Ethereum Sepolia (Security)                    │
├─────────────────────────────────────────────────────────────┤
│  4. TrustAnchorZK: Verify and store commitment              │
│     → submitZKCommitment(commitment, blockNum, proof)       │
│     → Groth16Verifier verifies proof ✅                     │
│     → Commitment stored on-chain                            │
│     → Event: ZKCommitmentStored                             │
│                                                              │
│  5. Anyone can verify:                                      │
│     → getZKCommitment(blockNum)                             │
│     → Returns: commitment, verified=true                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Features

### Privacy-Preserving
- ZK proofs hide sensitive data (stateRoot, validatorId, salt)
- Public only sees commitment hash and block number
- Perfect for financial institutions

### Security
- Ethereum-level security for Rayls commitments
- REAL cryptographic verification (not mocks)
- All contracts auditable on block explorers

### Flexibility
- Supports both ZK and transparent modes
- Can toggle ZK mode on/off
- Upgradeable verifier contract

### Production-Ready
- Comprehensive test coverage (24/24 tests)
- Gas-optimized (realistic costs)
- Proper access control
- Event logging for indexing

---

## 🚀 Quick Start Commands

### Check DemoAsset Balance
```bash
cast call 0x509Cdd429D01C4aB64431A8b4db8735a26f031F2 \
  "balanceOf(address)(uint256)" \
  0x8966caCc8E138ed0a03aF3Aa4AEe7B79118C420E \
  --rpc-url https://devnet-rpc.rayls.com
```

### Generate State Commitment on Rayls
```bash
cast send 0x8a74cCE7275eF27306163210695f3039F820bc17 \
  "generateStateRoot(bytes32,uint256)" \
  0xe7f1a75402a8ce4e2a14fbf1b5839e16320d3afd28d0a2202c48d08a10a45cac \
  100 \
  --rpc-url https://devnet-rpc.rayls.com \
  --private-key $PRIVATE_KEY
```

### Submit ZK Commitment to Ethereum
```bash
cast send 0xB512c3bf279c8222B55423f0D2375753F76dE2dC \
  "submitZKCommitment(bytes32,uint256,uint256,bytes32,uint256[8])" \
  0x21726f818bfde6ef03d4a77fc5ac785b86daafba1c932f553a2cf985a91870da \
  100 \
  $(cast block-number --rpc-url https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk) \
  0x0000000000000000000000000000000000000000000000000000000000000001 \
  "[17863004283804941110057119528671280031108086509786281072083332953226525840967,10733677236981470644945894584619418706937269997198853777456122904654640572909,2816324332338101265443586691783080741815369230188377221244030971536969439002,17262728235025506396548565903299937527543498924288633046100140555539146137408,16414200452151368744009120127259811270355758774780588963988343136776956456595,13302189960695360732829828302689351600151095226419378048416415821859019644722,11511439461660985645261522804983402206178846344477038625254505692391653877459,11706338943619448564728313747461358949542874959064253233329705162912985588989]" \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk \
  --private-key $PRIVATE_KEY
```

### Query ZK Commitment from Ethereum
```bash
cast call 0xB512c3bf279c8222B55423f0D2375753F76dE2dC \
  "hasZKCommitment(uint256)(bool)" \
  100 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk
```

---

## 📝 Notes

- All contracts deployed on **testnets** for demonstration
- Private key is for testnet use only (never commit to git!)
- For production, deploy TrustAnchorZK to Ethereum mainnet
- Consider multi-sig for admin functions in production
- Run security audit before mainnet deployment

---

**Deployment Complete**: November 19, 2025
**Status**: ✅ LIVE AND VERIFIED
**Tests**: 24/24 passing
**Ready for**: Hackathon demo, further development, production deployment (after audit)
