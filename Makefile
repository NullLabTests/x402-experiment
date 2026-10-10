SHELL := /bin/bash
FOUNDRY_BIN ?= /home/illy/.foundry/bin
PATH := $(FOUNDRY_BIN):$(PATH)

RPC_URL ?= http://127.0.0.1:8545
FACILITATOR_URL ?= http://127.0.0.1:8000
export RPC_URL FACILITATOR_URL

.DEFAULT_GOAL := help

## ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show available targets
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## ── Infrastructure ───────────────────────────────────────────────────────────
.PHONY: up down deploy fund flow status
up: ## Start Anvil + facilitator (127.0.0.1:8545 / :8000)
	@bash scripts/stack.sh start

down: ## Stop Anvil + facilitator
	@bash scripts/stack.sh stop

deploy: ## Deploy MockUSDC (idempotent)
	@python3 scripts/x402ctl.py deploy

fund: ## Fund Persona A with paper mUSDC
	@python3 scripts/x402ctl.py fund

flow: ## Run one payment: pay -> verify -> settle
	@python3 scripts/x402ctl.py flow

status: ## Print chain + token + balance status
	@python3 scripts/x402ctl.py status

## ── Gates ────────────────────────────────────────────────────────────────────
.PHONY: gate-0 gate-1 gate-2 gate-3 gate-4 gate-5 gate-6 gate-7 gates
setup: up deploy fund ## Alias: full local setup
gate-0: setup ## Gate 0: setup (Anvil, deploy, fund)

x402-smoke: setup ## Gate 1: x402 smoke test
	@echo "-> /verify"; curl -s $(FACILITATOR_URL)/verify; echo
	@echo "-> /settle"; curl -s -X POST $(FACILITATOR_URL)/settle \
		-H 'Content-Type: application/json' -d '{"payment_id":"smoke"}'; echo
	@echo "-> flow"; python3 scripts/x402ctl.py flow
gate-1: x402-smoke ## Gate 1: x402 smoke test

a2a-demo: ## Gate 2: A2A agent card
	@curl -s $(FACILITATOR_URL)/.well-known/agent.json | python3 -m json.tool
gate-2: a2a-demo ## Gate 2: A2A agent card

scenarios: ## Gate 3: scenario matrix
	@python3 scripts/scenarios.py
gate-3: scenarios ## Gate 3: scenario matrix

experiment: ## Gate 4: full integration test
	@python3 test_x402.py
gate-4: experiment ## Gate 4: full integration test

validation: ## Gate 5: validate running services
	@echo "anvil:       $$(curl -s -X POST $(RPC_URL) -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}')"
	@echo "facilitator: $$(curl -s $(FACILITATOR_URL)/verify)"
	@curl -s $(FACILITATOR_URL)/api/status | python3 -m json.tool
gate-5: validation ## Gate 5: validate running services

chaos: ## Gate 6: chaos-mode verification
	@bash scripts/chaos.sh
gate-6: chaos ## Gate 6: chaos-mode verification

final: ## Gate 7: H1-H5 hypothesis summary
	@curl -s $(FACILITATOR_URL)/api/h1h5 | python3 -m json.tool
gate-7: final ## Gate 7: H1-H5 hypothesis summary

gates: gate-0 gate-1 gate-2 gate-3 gate-4 gate-5 gate-6 gate-7 ## Run all gates

## ── Solidity ─────────────────────────────────────────────────────────────────
.PHONY: build forge-test fmt test
build: ## Compile contracts
	@forge build
forge-test: ## Run forge tests
	@forge test -vv
fmt: ## Format Solidity
	@forge fmt

test: forge-test experiment ## Run all tests (forge + integration)

## ── Cleanup ──────────────────────────────────────────────────────────────────
.PHONY: clean
clean: ## Stop services and remove local runtime state
	@bash scripts/stack.sh stop
	@rm -rf data cache
	@echo "cleaned"
