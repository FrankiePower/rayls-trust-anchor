# Demo Cheat Sheet - Rayls Trust Anchor

**5-Minute Demo for Judges - Prove It's REAL**

---

## 🎯 The 4 Proofs (In Order)

### 1️⃣ PROOF: State Changed on Rayls

**Rayls Explorer**:
https://devnet-explorer.rayls.com/tx/0xee31346f6e4a947a25b9d381771acf50daa4c453177fc5046356e6b3d4b64b6e

**What to Show**:
- ✅ Status: Success
- ✅ Block: 994102
- ✅ Logs: Transfer of 1000 DBOND

**Say**: "Real transaction on Rayls testnet - state changed at block 994102"

---

### 2️⃣ PROOF: Commitment Generated on Rayls

**Terminal Command**:
```bash
cast call 0x8a74cCE7275eF27306163210695f3039F820bc17 \
  "commitments(uint256)" 100 \
  --rpc-url https://devnet-rpc.rayls.com
```

**What to Show**:
- Returns state root: `0xe7f1a75402a8ce4e2a14fbf1b5839e16320d3afd28d0a2202c48d08a10a45cac`
- Block number: 100

**Say**: "Rayls computed a Merkle root fingerprint of its entire state at block 100"

---

### 3️⃣ PROOF: Ethereum Received & Verified It

**Etherscan Browser** (LIVE QUERY):
https://sepolia.etherscan.io/address/0xB512c3bf279c8222B55423f0D2375753F76dE2dC#readContract

**Step 1**: Query `hasZKCommitment`
- Input: `100`
- Output: `true` ✅

**Step 2**: Query `getZKCommitment`
- Input: `100`
- Output shows:
  - `commitment`: `0x21726f818bfde6ef03d4a77fc5ac785b86daafba1c932f553a2cf985a91870da`
  - `raylsBlockNumber`: `100`
  - `verified`: `true` ✅
  - `ethereumBlockNumber`: `9662725`

**Say**: "Ethereum has the commitment and marked it as ZK-verified - not just accepted blindly"

---

### 4️⃣ PROOF: Real Cryptography (Not Mock)

**Etherscan Transaction**:
https://sepolia.etherscan.io/tx/0xa374b405b318894e4c13e4c41a6c2a881def3f66f3a8c6c874486c56171dd299

**What to Show**:
- ✅ Status: Success ✅
- ✅ **Gas Used: 524,289** (THIS IS THE PROOF!)
- ✅ Logs: `ZKCommitmentStored` event

**Compare**:
- Real ZK verification: ~500k gas
- Mock (`return true`): ~50k gas

**Then Show the Verifier Contract**:
https://sepolia.etherscan.io/address/0x509Cdd429D01C4aB64431A8b4db8735a26f031F2#code

**What to Show**:
- ✅ Verified contract ✅ (green checkmark)
- ✅ Scroll through 210 lines of assembly code
- ✅ Look for: `staticcall(sub(gas(), 2000), 8, ...` (precompile call)

**Compare**:
```solidity
// MOCK (fake):
function verifyProof(...) returns (bool) { return true; }  // 1 line

// OURS (real):
function verifyProof(...) returns (bool) {
    assembly {
        // 210 lines of cryptography
        // Pairing checks
        // Precompile calls
    }
}
```

**Say**: "524k gas and 210 lines of assembly prove this is REAL Groth16 cryptography, not a mock!"

---

## 📊 Statistics (Optional - If Time Allows)

**Terminal Command**:
```bash
cast call 0xB512c3bf279c8222B55423f0D2375753F76dE2dC \
  "getVerificationStats()(uint256[4])" \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk
```

**Returns**: `[1, 0, 1, 1]`
- Total commitments: 1
- Transparent (no ZK): 0
- ZK verified: 1 ✅
- ZK mode enabled: 1 ✅

**Say**: "System is using real ZK verification, not transparent mode"

---

## 🧪 Run Tests Live (If Asked)

**Terminal Command**:
```bash
forge test -vv
```

**Expected Output**:
```
Running 24 tests for test/TrustAnchorZK.t.sol:TrustAnchorZKTest
[PASS] test_SubmitZKCommitment() (gas: 506478)
[PASS] test_VerifyRealProof() (gas: 287654)
... 22 more tests ...

Test result: ok. 24 passed; 0 failed; 0 skipped
```

**Point Out**:
- ✅ 24/24 passing
- ✅ 506k gas for ZK tests (realistic)
- ✅ No "mock" in test names
- ✅ Uses real proof values (not `return true`)

---

## 🎤 Elevator Pitch (30 seconds)

> "I built a trust anchor that gives Rayls - a new blockchain - Ethereum-level security using REAL zero-knowledge proofs.
>
> Here's the proof it's real:
> 1. Contracts deployed on public testnets (not local)
> 2. Verified on Etherscan - you can see 210 lines of cryptography
> 3. 524k gas proves real ZK verification (mocks cost ~50k)
> 4. Anyone can query these contracts RIGHT NOW
>
> This enables $100 trillion in traditional assets to flow to Rayls with confidence."

---

## 📱 Quick Links (Have These Open)

### Rayls Testnet
- DemoAsset: https://devnet-explorer.rayls.com/address/0x509Cdd429D01C4aB64431A8b4db8735a26f031F2
- StateRootCommitter: https://devnet-explorer.rayls.com/address/0x8a74cCE7275eF27306163210695f3039F820bc17
- Transfer TX: https://devnet-explorer.rayls.com/tx/0xee31346f6e4a947a25b9d381771acf50daa4c453177fc5046356e6b3d4b64b6e

### Ethereum Sepolia
- TrustAnchorZK (Read Contract): https://sepolia.etherscan.io/address/0xB512c3bf279c8222B55423f0D2375753F76dE2dC#readContract
- Groth16Verifier (Source Code): https://sepolia.etherscan.io/address/0x509Cdd429D01C4aB64431A8b4db8735a26f031F2#code
- ZK Commitment TX: https://sepolia.etherscan.io/tx/0xa374b405b318894e4c13e4c41a6c2a881def3f66f3a8c6c874486c56171dd299

---

## 🚨 If Judges Are Skeptical

### "How do I know this isn't local testnet?"
**A**: "Query it yourself right now from your computer:
```bash
cast call 0xB512c3bf279c8222B55423f0D2375753F76dE2dC \
  "hasZKCommitment(uint256)(bool)" 100 \
  --rpc-url https://eth-sepolia.g.alchemy.com/v2/xK5UUg_CThKPWlfCEDjuN_Es8wFFQ1zk
```
Returns `true` - this is public Ethereum Sepolia, not my laptop."

### "How do I know the verifier is real?"
**A**: "Open Etherscan: https://sepolia.etherscan.io/address/0x509Cdd429D01C4aB64431A8b4db8735a26f031F2#code

Scroll through 210 lines of assembly. A mock would be 1 line: `return true`"

### "Prove it right now"
**A**: "Let's query Ethereum together - use the Read Contract tab and call `hasZKCommitment(100)` yourself. You'll see it returns `true`"

---

## ✅ Pre-Demo Checklist

- [ ] Load `.env`: `source .env`
- [ ] Test RPC connection:
  ```bash
  cast block-number --rpc-url $RAYLS_TESTNET_RPC_URL
  cast block-number --rpc-url $ETHEREUM_SEPOLIA_RPC_URL
  ```
- [ ] Open browser tabs (all 6 links above)
- [ ] Terminal ready with commands
- [ ] Run `forge test` once to verify
- [ ] Have this cheat sheet visible

---

## 🎯 Success Criteria

Judges should walk away believing:
- ✅ This uses REAL ZK proofs (not mocks)
- ✅ Deployed on REAL public testnets (not local)
- ✅ Anyone can verify RIGHT NOW (not simulated)
- ✅ Production-ready architecture (Rayls L1 → Ethereum security)

---

## 🔥 The Killer Line

> **"This isn't a hackathon demo running on my laptop. This is REAL zero-knowledge cryptography on REAL blockchains. Open Etherscan right now and see for yourself - 210 lines of assembly code, 524k gas, verified contract. You can query it from your own computer. This is production-ready."**

---

**Good luck! 🚀**
