# Rayls Ethereum Trust Anchor

> **Bridging Rayls L1 to Ethereum Mainnet with Cryptographic State Commitments**

A smart contract system that implements the "plans to" feature from the Rayls litepaper (Section 3.3.6) - enabling Rayls L1 to inherit Ethereum's economic security through periodic state root commitments, censorship-resistant message passing, and verifiable state proofs.

---

## 🎯 Core Idea

**Problem**: Rayls L1 needs to inherit Ethereum's security guarantees without sacrificing its high performance (250k TPS, <1s finality).

**Solution**: Build a trust anchor system that:
1. **Periodically commits** Rayls L1 state roots to Ethereum mainnet
2. **Enables verification** - Anyone can prove Rayls state against Ethereum-anchored commitments
3. **Provides censorship resistance** - Users can force transaction inclusion via Ethereum if Rayls validators misbehave
4. **Maintains privacy** (optional ZK enhancement) - Hide actual state roots while proving validity

---

## 🏗️ Architecture

### Two-Chain Design

```
┌─────────────────────────────────────────────────────────────┐
│                    RAYLS L1 (Testnet)                       │
│                                                             │
│  📝 StateRootCommitter.sol                                  │
│     - Computes Merkle roots of block state                  │
│     - Batches every N blocks                                │
│     - Emits events for relayer                              │
│                                                             │
│  📬 MessageInbox.sol                                        │
│     - Receives messages from Ethereum                       │
│     - Ensures censorship resistance                         │
│                                                             │
│  🪙 DemoAsset.sol (ERC-20/1155)                             │
│     - Example tokenized asset                               │
│     - Generates state changes to anchor                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           │
                  ┌────────┴────────┐
                  │   Relayer       │
                  │   (Off-chain)   │
                  │  - Watches Rayls│
                  │  - Posts to ETH │
                  └────────┬─────────┘
                           │
┌─────────────────────────────────────────────────────────────┐
│                ETHEREUM MAINNET (Sepolia Testnet)           │
│                                                             │
│  ⚓ TrustAnchor.sol                                          │
│     - Stores state root commitments                         │
│     - Validates submitter signatures                        │
│     - Provides historical state queries                     │
│                                                             │
│  📤 MessageOutbox.sol                                       │
│     - Send messages to Rayls                                │
│     - Censorship-resistant queue                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 Smart Contracts

### MVP (5 Contracts)

| # | Contract | Chain | Purpose |
|---|----------|-------|---------|
| 1 | `StateRootCommitter.sol` | Rayls L1 | Generates and batches Merkle roots |
| 2 | `MessageInbox.sol` | Rayls L1 | Receives Ethereum messages |
| 3 | `DemoAsset.sol` | Rayls L1 | Example tokenized asset |
| 4 | `TrustAnchor.sol` | Ethereum | Stores and verifies state commitments |
| 5 | `MessageOutbox.sol` | Ethereum | Sends messages to Rayls |

### ZK-Enhanced (7 Contracts + 1 Circuit)

**Additional contracts if time permits:**

| # | Contract | Chain | Purpose |
|---|----------|-------|---------|
| 6 | `ZKVerifier.sol` | Ethereum | Auto-generated Groth16 verifier |
| 7 | `ProofRegistry.sol` | Ethereum | Verify state membership with ZK |

**ZK Circuit:**
- `circuits/state_verifier.circom` - Proves valid state exists without revealing the root

---

## 🎯 Key Features

### ✅ MVP Features (Must Have)

1. **State Root Commitments**
   - Rayls computes Merkle roots every N blocks
   - Posts to Ethereum via relayer
   - Stored immutably on Ethereum

2. **Verification System**
   - Anyone can verify Rayls state against Ethereum anchors
   - Merkle proof validation
   - Historical state queries

3. **Censorship Resistance**
   - Users can submit transactions via Ethereum
   - Rayls validators must process inbox messages
   - Economic penalties for censorship (future)

4. **Security Inheritance**
   - Rayls state backed by Ethereum's economic security
   - Dispute resolution via Ethereum
   - Disaster recovery capability

### 🚀 ZK Enhancement (Nice to Have)

5. **Privacy-Preserving Commitments**
   - Hide actual state roots using hash commitments
   - Zero-knowledge proofs of validity
   - Prevents timing analysis and correlation

6. **Private State Membership**
   - Prove "Account X had balance Y at block N"
   - Without revealing the state root
   - Selective disclosure for regulators

---

## 🛠️ Tech Stack

### Smart Contracts
- **Language**: Solidity ^0.8.20
- **Framework**: Foundry
- **Libraries**: OpenZeppelin (Merkle, Access Control)
- **Testing**: Forge

### ZK (Optional)
- **Circuit Language**: Circom 2.0
- **Proof System**: Groth16 (via SnarkJS)
- **Cryptography**: Poseidon hash, EdDSA signatures

### Off-Chain
- **Relayer**: TypeScript/Node.js
- **Libraries**: ethers.js/viem, @axelar-network/axelar-gmp-sdk
- **Monitoring**: Event listeners on both chains

---

## 🎪 Demo Flow

### Without ZK (Base Demo)
1. Deploy `DemoAsset` on Rayls, mint tokens → state changes
2. `StateRootCommitter` computes Merkle root every 10 blocks
3. Relayer picks up root, posts to `TrustAnchor` on Ethereum
4. User verifies their balance on Rayls using Ethereum-anchored proof
5. User submits censored transaction via `MessageOutbox` → forced inclusion

### With ZK (Enhanced Demo)
1. Same as above, but roots are hidden (only commitments visible)
2. ZK proof generated: "Valid state exists, signed by validators"
3. Ethereum verifies proof without seeing actual root
4. User proves state membership with second ZK proof

---

## 📊 Success Metrics

| Metric | Target | Why It Matters |
|--------|--------|----------------|
| **Gas Cost per Commitment** | <100k gas | Economically viable for frequent anchoring |
| **Verification Time** | <1 second | Fast enough for institutional use |
| **Relayer Latency** | <10 seconds | Near real-time anchoring |
| **Proof Generation** (ZK) | <30 seconds | Acceptable for privacy use case |

---

## 🏆 Why This Wins

1. **Implements Litepaper Vision**
   - Directly addresses Section 3.3.6: "Inherited Ethereum Security"
   - Fills a real gap in the Rayls ecosystem

2. **Production-Ready Architecture**
   - Clean separation of concerns
   - Extensible design (can add ZK later)
   - Real institutional use case

3. **Technical Depth**
   - Merkle proof verification
   - Cross-chain message passing
   - Optional ZK privacy layer
   - Censorship resistance mechanism

4. **Real-World Impact**
   - Enables $100T TradFi assets to flow securely
   - Institutions get Ethereum security guarantees
   - DeFi gets access to regulated assets

---

## 🚧 Development Phases

### Phase 1: Foundation (Hours 0-12)
- [ ] Set up Foundry project
- [ ] Deploy base 5 contracts
- [ ] Write comprehensive tests
- [ ] Build simple relayer
- [ ] End-to-end integration test
- **Deliverable**: Working MVP without ZK

### Phase 2: ZK Enhancement (Hours 12-24)
- [ ] Design Circom circuit
- [ ] Generate proving/verification keys
- [ ] Auto-generate `ZKVerifier.sol`
- [ ] Update `TrustAnchor` to verify proofs
- [ ] Update relayer to generate proofs
- **Deliverable**: Privacy-preserving trust anchor

### Phase 3: Demo & Polish (Hours 24-36)
- [ ] Simple frontend (optional)
- [ ] Demo video (2-3 minutes)
- [ ] Documentation
- [ ] GitHub polish
- **Deliverable**: Complete submission

---

## 📚 References

- **Rayls Litepaper**: Section 3.3.6 (Inherited Ethereum Security)
- **Rayls Docs**: https://docs.rayls.com
- **Rayls Discord**: https://discord.gg/6THZ96357r
- **Similar Projects**: Optimism L2OutputOracle, Arbitrum state commitments

---

## 🎬 Fallback Strategy

**If behind schedule:**
1. ✅ Submit base 5 contracts (solid hackathon project)
2. ❌ Skip ZK circuit (can add post-hackathon)
3. ❌ Skip fancy frontend (terminal demo is fine)
4. ✅ Focus on clean code + good documentation

**The base MVP alone is impressive** - ZK is the cherry on top.

---

## 👥 Team

- **Builder**: [Your Name/Team]
- **Hackathon**: Rayls DevConnect Buenos Aires 2025
- **Dates**: November 18-19, 2025
- **Prize Pool**: $100K+ (part of $1M+ Developer Program)

---

## 🚀 Getting Started

```bash
# Clone repository
git clone <repo-url>
cd rayls-trust-anchor

# Install dependencies
forge install

# Run tests
forge test

# Deploy to testnets
forge script script/Deploy.s.sol --rpc-url $RAYLS_RPC --broadcast
forge script script/DeployEthereum.s.sol --rpc-url $SEPOLIA_RPC --broadcast
```

---

## 📝 License

MIT

---

**Status**: 🚧 In Development
**Last Updated**: November 19, 2025
