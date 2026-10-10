"""Minimal web3 helpers for the x402 paper-trading GUI.

Talks to a local Anvil node (chain id 31337) and a self-deployed MockUSDC
token. All value here is worthless paper tokens on localhost.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from hexbytes import HexBytes
from web3 import Web3

ROOT = Path(__file__).resolve().parent.parent
ARTIFACT = ROOT / "out" / "MockUSDC.sol" / "MockUSDC.json"
RUNTIME = ROOT / "data" / "runtime.json"

RPC_URL = "http://127.0.0.1:8545"
CHAIN_ID = 31337

DEPLOYER_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
PERSONA_A_KEY = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

INITIAL_SUPPLY = 1_000_000  # raw units (6 decimals -> 1.0 mUSDC)
FUND_AMOUNT = 500_000
PAYMENT_AMOUNT = 100_000
GAS_PRICE = 1_000_000_000

TRANSFER_TOPIC = (
    "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
)


def _load_artifact() -> dict[str, Any]:
    with open(ARTIFACT) as fh:
        return json.load(fh)


def _load_runtime() -> dict[str, Any]:
    if RUNTIME.exists():
        try:
            return json.loads(RUNTIME.read_text())
        except Exception:
            return {}
    return {}


def _save_runtime(data: dict[str, Any]) -> None:
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.write_text(json.dumps(data, indent=2))


def get_w3() -> Web3:
    return Web3(Web3.HTTPProvider(RPC_URL, request_kwargs={"timeout": 5}))


def _artifact():
    art = _load_artifact()
    return art["abi"], HexBytes(art["bytecode"]["object"])


def _acct(w3: Web3, key: str):
    return w3.eth.account.from_key(key)


def _send(w3: Web3, key: str, tx: dict[str, Any]) -> dict[str, Any]:
    acct = _acct(w3, key)
    tx.setdefault("chainId", CHAIN_ID)
    if "maxFeePerGas" not in tx and "gasPrice" not in tx:
        tx["gasPrice"] = GAS_PRICE
    tx["nonce"] = w3.eth.get_transaction_count(acct.address)
    try:
        tx["gas"] = w3.eth.estimate_gas(tx)
    except Exception:
        tx.setdefault("gas", 500_000)
    signed = w3.eth.account.sign_transaction(tx, key)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=30)
    return {
        "hash": tx_hash.hex(),
        "status": receipt.status,
        "gas": receipt.gasUsed,
        "receipt": receipt,
    }


def _parse_transfer(receipt) -> dict[str, Any] | None:
    for log in receipt.logs:
        if log.topics and ("0x" + log.topics[0].hex().lower()) == TRANSFER_TOPIC:
            frm = "0x" + log.topics[1].hex()[-40:]
            to = "0x" + log.topics[2].hex()[-40:]
            value = int(log.data.hex(), 16) if log.data else 0
            return {"from": frm, "to": to, "value": value}
    return None


def contract_address(w3: Web3) -> str:
    rt = _load_runtime()
    addr = rt.get("contract")
    if addr:
        code = w3.eth.get_code(Web3.to_checksum_address(addr))
        if len(code) > 0:
            return Web3.to_checksum_address(addr)
    return ""


def deploy(w3: Web3) -> dict[str, Any]:
    existing = contract_address(w3)
    if existing:
        return {"address": existing, "deployed": True, "reused": True}

    abi, bytecode = _artifact()
    acct = _acct(w3, DEPLOYER_KEY)
    factory = w3.eth.contract(abi=abi, bytecode=bytecode)
    tx = factory.constructor(INITIAL_SUPPLY).build_transaction(
        {
            "from": acct.address,
            "nonce": w3.eth.get_transaction_count(acct.address),
            "chainId": CHAIN_ID,
            "gasPrice": GAS_PRICE,
            "gas": 2_000_000,
        }
    )
    signed = w3.eth.account.sign_transaction(tx, DEPLOYER_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=60)
    addr = Web3.to_checksum_address(receipt.contractAddress)
    _save_runtime({"contract": addr, "deploy_tx": tx_hash.hex()})
    return {
        "address": addr,
        "deployed": True,
        "reused": False,
        "hash": tx_hash.hex(),
        "gas": receipt.gasUsed,
    }


def token_meta(w3: Web3, addr: str) -> dict[str, Any]:
    abi, _ = _artifact()
    c = w3.eth.contract(address=Web3.to_checksum_address(addr), abi=abi)
    return {
        "name": c.functions.name_().call(),
        "symbol": c.functions.symbol_().call(),
        "decimals": c.functions.decimals_().call(),
    }


def balances(w3: Web3, addr: str) -> dict[str, int]:
    abi, _ = _artifact()
    c = w3.eth.contract(address=Web3.to_checksum_address(addr), abi=abi)
    deployer = _acct(w3, DEPLOYER_KEY).address
    a = _acct(w3, PERSONA_A_KEY).address
    b = w3.eth.accounts[2]
    return {
        "deployer": c.functions.balanceOf(deployer).call(),
        "persona_a": c.functions.balanceOf(a).call(),
        "persona_b": c.functions.balanceOf(b).call(),
    }


def fund(w3: Web3, addr: str) -> dict[str, Any]:
    abi, _ = _artifact()
    c = w3.eth.contract(address=Web3.to_checksum_address(addr), abi=abi)
    persona_a = _acct(w3, PERSONA_A_KEY).address
    tx = c.functions.transfer(persona_a, FUND_AMOUNT).build_transaction(
        {"from": _acct(w3, DEPLOYER_KEY).address, "gas": 500_000}
    )
    res = _send(w3, DEPLOYER_KEY, tx)
    return {"hash": res["hash"], "status": res["status"], "gas": res["gas"]}


def pay(w3: Web3, addr: str) -> dict[str, Any]:
    """Persona A pays Persona B, the x402 payment leg."""
    abi, _ = _artifact()
    c = w3.eth.contract(address=Web3.to_checksum_address(addr), abi=abi)
    persona_b = w3.eth.accounts[2]
    tx = c.functions.transfer(persona_b, PAYMENT_AMOUNT).build_transaction(
        {"from": _acct(w3, PERSONA_A_KEY).address, "gas": 500_000}
    )
    res = _send(w3, PERSONA_A_KEY, tx)
    event = _parse_transfer(res["receipt"])
    return {
        "hash": res["hash"],
        "status": res["status"],
        "gas": res["gas"],
        "event": event,
    }


def status() -> dict[str, Any]:
    w3 = get_w3()
    try:
        connected = w3.is_connected()
    except Exception:
        connected = False
    if not connected:
        return {"rpc_connected": False, "chain_id": None, "block": None}

    addr = contract_address(w3)
    out: dict[str, Any] = {
        "rpc_connected": True,
        "chain_id": w3.eth.chain_id,
        "block": w3.eth.block_number,
        "contract": addr,
        "deployed": bool(addr),
    }
    if addr:
        out["token"] = token_meta(w3, addr)
        out["balances"] = balances(w3, addr)
    return out
