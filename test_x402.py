#!/usr/bin/env python3
"""x402 smoke test: simulate paper-trading payment flow with MockUSDC."""

import json
import time
from web3 import Web3

w3 = Web3(Web3.HTTPProvider('http://127.0.0.1:8545'))

with open('/home/illy/x402/config.json') as f:
    cfg = json.load(f)

# Load MockUSDC ABI
with open('/home/illy/x402/out/MockUSDC.sol/MockUSDC.json') as f:
    artifact = json.load(f)
abi = artifact['abi']

mockusdc = w3.eth.contract(address=cfg['mockusdc_address'], abi=abi)

ACCOUNT_A = cfg['persona_a']
ACCOUNT_B = cfg['persona_b']

print(f"Account A: {ACCOUNT_A}")
print(f"Account B: {ACCOUNT_B}")
print(f"MockUSDC: {cfg['mockusdc_address']}")

# Check initial balances
bal_a = w3.from_wei(mockusdc.functions.balanceOf(ACCOUNT_A).call(), 'ether')
bal_b = w3.from_wei(mockusdc.functions.balanceOf(ACCOUNT_B).call(), 'ether')
print(f"\nInitial balances - A: {bal_a}, B: {bal_b}")

# Fund Account A with USDC (mint 10000)
print("\nMinting 10000 USDC to Account A...")
# MockUSDC doesn't have a mint function from outside, so we need to use the contract creator
# Actually, let's check if we can transfer from the deployer or use foundry to mint

# Let's try transferring from account A to B using transferWithAuthorization (x402 style)
# First, let's just do a regular transfer
print("\n--- Regular transfer ---")
tx = mockusdc.functions.transfer(ACCOUNT_B, 100)
tx_build = tx.build_transaction({
    'from': ACCOUNT_A,
    'nonce': w3.eth.get_transaction_count(ACCOUNT_A),
    'chainId': cfg['chain_id'],
    'gas': 100000,
})
signed = w3.eth.account.sign_transaction(tx_build, '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print(f"Transfer status: {receipt.status}, gas used: {receipt.gasUsed}")

bal_a = w3.from_wei(mockusdc.functions.balanceOf(ACCOUNT_A).call(), 'ether')
bal_b = w3.from_wei(mockusdc.functions.balanceOf(ACCOUNT_B).call(), 'ether')
print(f"Balances after transfer - A: {bal_a}, B: {bal_b}")

# Now test the x402 flow: transferWithAuthorization
print("\n--- transferWithAuthorization (x402 style) ---")
# In x402, the payer approves a transfer with authorization via EIP-712/EIP-3009
# transferWithAuthorization takes: to, amount, nonce, expires
nonce_bytes = '0x' + '00' * 32  # simple nonce
expires_bytes = '0x' + 'ff' * 32  # far future

tx_auth = mockusdc.functions.transferWithAuthorization(
    ACCOUNT_B, 50, nonce_bytes, expires_bytes
)
tx_auth_build = tx_auth.build_transaction({
    'from': ACCOUNT_A,
    'nonce': w3.eth.get_transaction_count(ACCOUNT_A),
    'chainId': cfg['chain_id'],
    'gas': 100000,
})
signed_auth = w3.eth.account.sign_transaction(tx_auth_build, '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80')
tx_hash_auth = w3.eth.send_raw_transaction(signed_auth.raw_transaction)
receipt_auth = w3.eth.wait_for_transaction_receipt(tx_hash_auth)
print(f"transferWithAuthorization status: {receipt_auth.status}, gas used: {receipt_auth.gasUsed}")

bal_a = w3.from_wei(mockusdc.functions.balanceOf(ACCOUNT_A).call(), 'ether')
bal_b = w3.from_wei(mockusdc.functions.balanceOf(ACCOUNT_B).call(), 'ether')
print(f"Balances after auth transfer - A: {bal_a}, B: {bal_b}")

# Test /verify endpoint
import urllib.request
print("\n--- /verify endpoint ---")
verify_url = f"{cfg['facilitator_url']}/verify"
try:
    req = urllib.request.Request(verify_url)
    with urllib.request.urlopen(req, timeout=5) as resp:
        print(f"GET {verify_url} -> {resp.read().decode()}")
except Exception as e:
    print(f"GET {verify_url} -> Error: {e}")

# Test /settle endpoint
print("\n--- /settle endpoint ---")
settle_url = f"{cfg['facilitator_url']}/settle"
try:
    import urllib.request
    data = json.dumps({"payment_id": "test-payment-123"}).encode()
    req = urllib.request.Request(
        settle_url,
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        print(f"POST {settle_url} -> {resp.read().decode()}")
except Exception as e:
    print(f"POST {settle_url} -> Error: {e}")

print("\n=== x402 smoke test complete ===")