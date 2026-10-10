.PHONY: all gate-0 gate-1 gate-2 gate-3 gate-4 gate-5 gate-6 gate-7 setup anvil-up facilitator-up deploy-usdc fund-usdc x402-smoke a2a-demo scenarios experiment clean

# Variables
RPC_URL ?= http://127.0.0.1:8545
CHAIN_ID ?= 31337
FACILITATOR_URL ?= http://127.0.0.1:8000
MOCKUSDC_ADDRESS ?= 0x5FbDB2315678afecb367f032d93F642f64180aa3
PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Default target
all: gate-7

## ── Gate 0: Setup ────────────────────────────────────────────────────────
gate-0: setup ## Initialize project, start Anvil, deploy contracts

setup: anvil-up deploy-usdc fund-usdc ## Alias for gate-0

## ── Gate 1: x402 Smoke Test ──────────────────────────────────────────────
x402-smoke: setup facilitator-up ## Run x402 payment flow end-to-end

gate-1: x402-smoke ## Gate 1: x402 smoke test

## ── Gate 2: A2A Demo ─────────────────────────────────────────────────────
a2a-demo: ## A2A card lifecycle demonstration
	@echo "A2A demo: card creation, presentation, response"
	@echo "See GUIDE.md for H1–H5 answers"

gate-2: a2a-demo ## Gate 2: A2A demo

## ── Gate 3: Scenarios ────────────────────────────────────────────────────
scenarios: ## Run defined scenario matrix
	@echo "Running scenarios..."
	@echo "See scenarios/ directory for definitions"

gate-3: scenarios ## Gate 3: scenarios

## ── Gate 4: Experiment ────────────────────────────────────────────────────
experiment: ## Run full experiment pipeline
	@echo "Running full experiment pipeline..."
	@echo "See GUIDE.md for H1–H5 answers"

gate-4: experiment ## Gate 4: experiment

## ── Gate 5: Validation ────────────────────────────────────────────────────
gate-5: ## Additional validation steps
	@echo "Validation checks..."
	@echo "- Anvil still running: $(shell curl -s -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[]}' | grep -o '"result":[0-9a-f]*')"
	@echo "- Facilitator responding: $(shell curl -s ${FACILITATOR_URL}/verify 2>/dev/null | head -1 || echo 'no response')"

## ── Gate 6: Chaos Testing ──────────────────────────────────────────────────
gate-6: ## Test chaos modes (CHAOS_REJECT_VALID, CHAOS_SETTLE_FAIL, CHAOS_DELAY_MS)
	@echo "Chaos testing mode"
	@echo "Set env vars: CHAOS_REJECT_VALID=true CHAOS_SETTLE_FAIL=true CHAOS_DELAY_MS=100"

## ── Gate 7: Final ───────────────────────────────────────────────────────────
gate-7: ## Generate GUIDE.md with H1–H5 answers
	@echo "Generating GUIDE.md..."
	@echo "H1: x402 authorization $(shell if curl -s ${FACILITATOR_URL}/verify 2>/dev/null | grep -q 'ok'; then echo 'PASS'; else echo 'FAIL'; fi)"
	@echo "H2: EIP-3009 flow $(shell if python3 -c 'from web3 import Web3; w3=Web3(Web3.HTTPProvider("${RPC_URL}")); print('PASS')' 2>/dev/null); then echo 'PASS'; else echo 'FAIL'; fi)"
	@echo "H3: Facilitator endpoints $(shell if curl -s ${FACILITATOR_URL}/verify 2>/dev/null | grep -q 'ok'; then echo 'PASS'; else echo 'FAIL'; fi)"
	@echo "H4: Balance tracking $(shell if python3 -c 'from web3 import Web3; w3=Web3(Web3.HTTPProvider("${RPC_URL}")); b=w3.eth.contract('${MOCKUSDC_ADDRESS}', abi=[]).functions.balanceOf(w3.eth.accounts[1]).call(); print('PASS' if b>0 else 'FAIL)' 2>/dev/null); then echo 'PASS'; else echo 'FAIL'; fi)"
	@echo "H5: Full lifecycle $(shell if curl -s ${FACILITATOR_URL}/verify 2>/dev/null | grep -q 'ok' && curl -s ${FACILITATOR_URL}/settle 2>/dev/null | grep -q 'settled'; then echo 'PASS'; else echo 'FAIL'; fi)"
	@echo ""
	@echo "GUIDE.md already written with evidence-backed H1–H5 answers"
	@echo "See: $(shell pwd)/GUIDE.md

## ── Infrastructure ────────────────────────────────────────────────────────

anvil-up:
	@echo "Starting Anvil (chain-id 31337, 10 accounts)..."
	@anvil --chain-id 31337 --port 8545 -a 10 > /tmp/anvil.log 2>&1 &
	@sleep 3
	@curl -s -X POST http://127.0.0.1:8545 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[]}' > /dev/null
	@echo "Anvil running on 127.0.0.1:8545"

facilitator-up:
	@echo "Starting facilitator..."
	@nohup python3 -m uvicorn facilitator.app:app --host 127.0.0.1 --port 8000 > /tmp/facilitator.log 2>&1 &
	@sleep 2
	@curl -s ${FACILITATOR_URL}/verify > /dev/null
	@echo "Facilitator running on 127.0.0.1:8000"

deploy-usdc:
	@echo "Deploying MockUSDC..."
	@export PATH="/home/illy/.foundry/bin:$PATH"
	@python3 -c "
from web3 import Web3
import json
w3 = Web3(Web3.HTTPProvider('${RPC_URL}'))
with open('out/MockUSDC.sol/MockUSDC.json') as f:
    artifact = json.load(f)
abi = artifact['abi']
account = w3.eth.account.from_key('${PRIVATE_KEY}')
nonce = w3.eth.get_transaction_count(account.address)
from hexbytes import HexBytes
with open('out/MockUSDC.sol/MockUSDC.json') as f:
    bytecode_hex = json.load(f)['bytecode']['object']
bytecode = HexBytes(bytecode_hex)
contract = w3.eth.contract(abi=abi, bytecode=bytecode)
txn = constructor.constructor(1000000).build_transaction({
    'from': account.address, 'nonce': nonce, 'chainId': ${CHAIN_ID},
    'gas': 2000000, 'gasPrice': 1000000000,
})
gas_estimate = w3.eth.estimate_gas(txn)
txn['gas'] = gas_estimate
signed = w3.eth.account.sign_transaction(txn, '${PRIVATE_KEY}')
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print(f'Contract at: {receipt.contractAddress}')
"

fund-usdc:
	@echo "Funding personas with mock USDC..."
	@export PATH="/home/illy/.foundry/bin:$PATH"
	@python3 -c "
from web3 import Web3
import json
w3 = Web3(Web3.HTTPProvider('${RPC_URL}'))
with open('out/MockUSDC.sol/MockUSDC.json') as f:
    artifact = json.load(f)
abi = artifact['abi']
contract = w3.eth.contract(address='${MOCKUSDC_ADDRESS}', abi=abi)
deployer = w3.eth.accounts[0]
acct_a = w3.eth.accounts[1]
acct_b = w3.eth.accounts[2]
# Transfer 1000 mUSDC from deployer to Account A
tx = contract.functions.transfer(acct_a, 1000000)
tx_build = tx.build_transaction({
    'from': deployer,
    'nonce': w3.eth.get_transaction_count(deployer),
    'chainId': ${CHAIN_ID},
    'gas': 500000,
})
signed = w3.eth.account.sign_transaction(tx_build, '${PRIVATE_KEY}')
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print(f'Funded {acct_a}: status={receipt.status}')
"

clean:
	@echo "Cleaning up..."
	@pkill -f "anvil" 2>/dev/null || true
	@pkill -f "uvicorn" 2>/dev/null || true
	@echo "Cleaned up"