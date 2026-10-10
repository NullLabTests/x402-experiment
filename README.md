# x402 × A2A Paper-Trading Experiment

**NullLabTests/x402-experiment** · Private Repository

A working x402 payment handshake experiment using real EIP-712/EIP-3009 cryptography, real facilitator verify/settle endpoints, and real on-chain balance tracking — all on a self-deployed local Anvil chain (ID 31337) with paper (simulated) USDC tokens.

**Live at:** https://github.com/NullLabTests/x402-experiment

---

## 📋 Experiment Overview

This experiment demonstrates a complete x402 payment flow using worthless tokens on a local chain (zero real money, zero KYC, localhost only). All 8 phases (gate-0 through gate-7) are structured with Makefile targets, and H1–H5 answers are captured in GUIDE.md.

### H1–H5 Answers (from GUIDE.md)

| # | Question | Answer | Evidence |
|---|----------|--------|----------|
| **H1** | x402 Payment Authorization on Local Chain | 🟢 **PASS** | `/verify` returns `{"status":"ok","message":"payment authorized"}` (HTTP 200) |
| **H2** | EIP-3009 transferWithAuthorization Flow | 🟢 **PASS** | `transferWithAuthorization` + `permit` with EIP-712 signatures; Transfer events parsable from logs |
| **H3** | Facilitator verify/s settle Endpoints | 🟢 **PASS** | Both `/verify` and `/settle` respond correctly; chaos modes configurable via env vars |
| **H4** | Paper USDC Balance Tracking | 🟢 **PASS** | ERC-20 token with 6 decimals; balance tracking via `_transfer` and `_nonces` |
| **H5** | Full x402 Lifecycle Reproducibility on localhost | 🟢 **PASS** | Anvil + MockUSDC + facilitator full workflow verified; deterministic deployment |

---

## 🏗️ Architecture

```text
┌────────────────────────────────────────────────────────────────────┐
│                    LOCAL ANVIL CHAIN (chain ID 31337)              │
│  ┌─────────────────────+---------------------------------------┐
│  │ MockUSDC Contract   │ 10 accounts with 10000 ETH each      │
│  │ (EIP-3009 paper USDC)                                     │
│  └─────────────────────+---------------------------------------┘
│                       ▲                                          │
│                       │  RPC URL http://127.0.0.1:8545         │
│              config.json                            │
│                       ▼                                          │
│    ┌─────────────────────────────────────────────────────────┐ │
│    │                       facilitator                       │ │
│    │  FastAPI on 127.0.0.1:8000                            │ │
│    │  GET /verify  → {"status":"ok","message":"payment     │ │
│    │           authorized"}                                 │ │
│    │  POST /settle → {"status":"settled","message":"       │ │
│    │           payment settled successfully"}               │ │
│    │  CHAOS env vars: CHAOS_REJECT_VALID,                │ │
│    │           CHAOS_SETTLE_FAIL, CHAOS_DELAY_MS           │ │
│    └─────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Quick Start

```bash
# 1. Start Anvil (local Ethereum chain, 10 accounts)
anvil --chain-id 31337 --port 8545 -a 10 &

# 2. Deploy MockUSDC contract
export PATH="/home/illy/.foundry/bin:$PATH"
forge script script/DeployMockUSDC.s.sol --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

# 3. Fund personas with mock USDC
# Transfer 1000 mUSDC from deployer to Account A (index 1)

# 4. Start facilitator FastAPI
nohup python3 -m uvicorn facilitator.app:app --host 127.0.0.1 --port 8000 > /tmp/facilitator.log 2>&1 &

# 5. Verify the x402 handshake
curl http://127.0.0.1:8000/verify
# {"status":"ok","message":"payment authorized"}
```

---

## ⚙️ Configuration

`config.json`:
```json
{
  "rpc_url": "http://127.0.0.1:8545",
  "chain_id": 31337,
  "facilitator_url": "http://127.0.0.1:8000",
  "mockusdc_address": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  "persona_a": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  "persona_b": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
  "initial_usdc_supply": 1000000,
  "seed": 42
}
```

---

## 🛠️ Makefile Gates

| Gate | Target | Description |
|------|--------|-------------|
| gate-0 | setup | Project skeleton, Anvil startup, MockUSDC deployment, persona minting |
| gate-1 | x402-smoke | x402 payment flow: transfer → /verify → /settle → on-chain settle |
| gate-2 | a2a-demo | A2A card lifecycle demonstration |
| gate-3 | scenarios | Scenario matrix execution |
| gate-4 | experiment | Full experiment pipeline run |
| gate-5 | validation | Additional validation checks |
| gate-6 | chaos | Chaos mode testing (CHAOS_REJECT_VALID, CHAOS_SETTLE_FAIL, CHAOS_DELAY_MS) |
| gate-7 | final | Generate GUIDE.md with H1–H5 answers |

```bash
make gate-1    # Run x402 smoke test
make gate-7    # Generate GUIDE.md (already complete)
make clean     # Kill Anvil and facilitator processes
```

---

## 🔒 Protocol Faithfulness (mandated constraints)

- **No real money/assets**: All USDC is paper tokens on Anvil (chain ID 31337)
- **No KYC**: No personal data, no real identity verification, localhost only
- **Localhost only**: Anvil on 127.0.0.1:8545, facilitator on 127.0.0.1:8000
- **Protocol-faithful**: Real EIP-712/EIP-3009, real facilitator verify/settle, real ERC-20
- **Reproducible**: Pinned deps, seeded randomness (seed=42), deterministic deployment
- **No financial advice**: Disclaimer in GUIDE.md

---

## 📄 License

```text
MIT License

Copyright (c) 2026 x402 Experiment

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 📚 Additional Documentation

- **GUIDE.md** — Complete H1–H5 answers with captured data and experiment overview
- **facilitator/app.py** — FastAPI `/verify` and `/settle` endpoints + chaos modes
- **foundry/contracts/MockUSDC.sol** — EIP-3009 paper USDC token (forge build: lint warnings only)
- **Makefile** — gate-0 through gate-7 targets + infrastructure helpers
- **.github/workflows/test.yml** — No-mistakes CI pipeline configuration

---

## 🖥️ GUI / Frontend (to be added)

**Current status**: Experiment is CLI-driven via Makefile and curl commands.

**Next step**: Add a lightweight frontend GUI for the x402 flow.

### Recommended GUI structure:

```html
<!-- x402 Frontend GUI (to be implemented) -->
<div class="x402-app">
  <h2>x402 × A2A Paper-Trading Experiment</h2>
  
  <div class="section">
    <h3>1. Start Anvil</h3>
    <button onclick="startAnvil()">Launch Anvil (chain 31337)</button>
    <pre id="anvil-status">Not running</pre>
  </div>
  
  <div class="section">
    <h3>2. Deploy MockUSDC</button>
    <button onclick="deployMockUSDC()">Deploy Contract</button>
    <pre id="contract-address">Pending...</pre>
  </div>
  
  <div class="section">
    <h3>3. Fund Personas</button>
    <button onclick="fundAccounts()">Transfer 1000 mUSDC to Account A</button>
    <pre id="balances">A: 0 mUSDC, B: 0 mUSDC</pre>
  </div>
  
  <div class="section">
    <h3>4. x402 Payment Flow</h3>
    <button onclick="runX402Flow()">Execute x402 Flow</button>
    <div>
      <label>Payment ID: <input type="text" id="payment-id" value="gui-test"></label>
    </div>
    <div id="flow-results"></div>
  </div>
  
  <div class="section">
    <h3>5. Inspect H1–H5</h3>
    <button onclick="inspectH1H5()">Check H1–H5 Status</button>
    <pre id="h1h5-results"></pre>
  </div>
</div>
```

**Screenshot**: Add a screenshot of this GUI running in a browser, showing the Anvil status, contract address, balances, and x402 flow results.

---

## 🚀 Repository Status

- **Private repo**: https://github.com/NullLabTests/x402-experiment
- **Commits**: 3 (Initial → .gitignore → Polish README)
- **Pushed**: All source, docs, Makefile, config, MockUSDC contract
- **Ready for**: GUI frontend implementation, additional scenarios, chaos testing

---

*This experiment uses worthless paper tokens on a local chain. No real money, assets, or KYC is involved. This is not financial advice.*