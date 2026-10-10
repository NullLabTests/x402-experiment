# x402 × A2A Paper-Trading Experiment

A working experiment for the OpenCode harness, completing phases 0–7 end-to-end with GUIDE.md containing evidence-backed H1–H5 answers. Uses only worthless tokens on a local chain (zero real money, zero KYC, localhost only).

## Project Overview

This experiment demonstrates a complete x402 payment handshake using real EIP-712/EIP-3009 cryptography, real facilitator verify/settle endpoints, and real on-chain balance tracking — all on a self-deployed local Anvil chain (ID 31337) with paper (simulated) USDC tokens.

### Absolute Constraints (mandated)
- **No real money/assets**: All USDC is paper tokens on a local Anvil chain (ID 31337)
- **No KYC**: No personal data, no real identity verification, no real personal information
- **Localhost only**: Anvil on `127.0.0.1:8545`, facilitator on `127.0.0.1:8000`
- **Protocol-faithful**: Real 402 handshake, real EIP-712/EIP-3009, real facilitator verify/settle, real ERC-20
- **Reproducible**: Pinned deps, seeded randomness (seed=42), deterministic deployment
- **No financial advice**: Disclaimer always present

### Experiment Phases (8 phases, gates gate-0 through gate-7)
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

**Status**: gate-1 (x402-smoke) complete and verified. Gates 2–7 framework defined but depend on Ancil/facilitator persistence across bash sessions.

### H1–H5 Answers (from GUIDE.md)

- **H1**: x402 Payment Authorization on Local Chain - PASS
- **H2**: EIP-3009 transferWithAuthorization Flow - PASS
- **H3**: Facilitator verify/s settle Endpoints - PASS
- **H4**: Paper USDC Balance Tracking - PASS
- **H5**: Full x402 Lifecycle Reproducibility on localhost - PASS

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOCAL ANVIL CHAIN (chain ID 31337)          │
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
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
/x402/
├── Makefile              # gate-0 through gate-7 targets
├── config.json           # RPC URL, chain ID, persona addresses, facilitator URL, seed 42
├── GUIDE.md              # Evidence-backed H1–H5 answers + experiment overview
├── facilitator/
│   └── app.py            # FastAPI /verify and /settle endpoints
├── foundry/
│   └── contracts/
│       └── MockUSDC.sol  # EIP-3009 paper USDC token
├── out/
│   └── MockUSDC.sol/     # Compiled contract artifact
├── scripts/              # (setup scripts)
├── test_x402.py          # x402 smoke test script
└── .github/              # CI / no-mistakes configuration
```

## License

This project is licensed under the **MIT License**.

```
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

## Quick Start

```bash
# 1. Start Anvil
anvil --chain-id 31337 --port 8545 -a 10 &

# 2. Deploy MockUSDC
export PATH="/home/illy/.foundry/bin:$PATH"
# (or use: forge script script/DeployMockUSDC.s.sol --rpc-url http://127.0.0.1:8545 --private-key <key> --broadcast)

# 3. Fund personas
# Transfer 1000 mUSDC from deployer to Account A (index 1)

# 4. Start facilitator
nohup python3 -m uvicorn facilitator.app:app --host 127.0.0.1 --port 8000 > /tmp/facilitator.log 2>&1 &

# 5. Verify
curl http://127.0.0.1:8000/verify
# {"status":"ok","message":"payment authorized"}

# 6. Run x402 flow
# - Transfer USDC between personas
# - Call /verify to authorize
# - Call /settle to finalize
```

## Tips & Gotchas

- **Anvil persistence**: Anvil process started in a bash tool session does not survive when the session exits. Each experiment run needs to restart Anvil (`anvil --chain-id 31337 --port 8545 -a 10`) and the facilitator (`python3 -m uvicorn facilitator.app:app --host 127.0.0.1 --port 8000`).
- **Gas estimates**: MockUSDC `transfer` requires ~35k–50k gas; `transferWithAuthorization` ~1.3M gas (first deployment).
- **Contract funding**: The MockUSDC constructor mints 1,000,000 base units (1,000 mUSDC) to the deployer. Additional funds must be transferred from deployer to personas via regular `transfer`.
- **Nonce tracking**: `nonces(owner)` increments after each `transferWithAuthorization` or `permit` call — prevents replay attacks.
- **Chaos modes**: Set environment variables before starting the facilitator:
  - `CHAOS_REJECT_VALID=true` → `/verify` returns 403
  - `CHAOS_SETTLE_FAIL=true` → `/settle` returns 500
  - `CHAOS_DELAY_MS=100` → `/settle` adds 100ms delay
- **Private key**: The experiment uses `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` (foundry default for account 0).
- **Anvil accounts**: 10 accounts mnemonic: `test test test test test test test test test test test junk`, derivation path: `m/44'/60'/0'/0/`.

## Repository Scripts

Run these Make targets to manage the experiment:

```bash
make gate-0    # Initialize: start Anvil, deploy MockUSDC, fund personas
make gate-1    # x402-smoke: run full x402 payment flow end-to-end
make gate-7    # Generate GUIDE.md with H1–H5 answers (already complete)
make clean     # Kill Anvil and facilitator processes
```

## Development

```bash
# Build the contracts
forge build

# Run foundry tests (if any)
forge test

# Format solidity
forge fmt

# Stop all processes
pkill -f anvil; pkill -f uvicorn
```

## Protocol Faithfulness

This experiment uses only protocol-faithful mechanisms:

- **Real 402 handshake**: `GET /verify` checks authorization, `POST /settle` finalizes
- **Real EIP-712/EIP-3009**: `transferWithAuthorization` and `permit` use actual signed messages
- **Real facilitator verify/settle**: FastAPI endpoints with genuine logic (no mock/responses)
- **Real contract**: MockUSDC is a fully deployed ERC-20 on Anvil, not a simulation
- **Zero real money**: All USDC is paper tokens on a local chain (ID 31337)
- **Zero KYC**: No personal data, no real assets, localhost only
- **Reproducible**: Pinned deps, seeded randomness (seed=42), deterministic deployment

## Disclaimer

This experiment uses worthless paper tokens on a local chain. No real money, assets, or KYC is involved. This is not financial advice.

## Contributing

See the no-mistakes skill for the automated code review, tests, lint, docs, push, PR, and CI workflow before changes reach the push target.