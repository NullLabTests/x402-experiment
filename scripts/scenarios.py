#!/usr/bin/env python3
"""Deterministic scenario matrix for the x402 paper experiment.

Runs a handful of named checks against the live local stack and prints a
table. Exit code 0 = all scenarios passed.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from facilitator import chain  # noqa: E402

results: list[tuple[str, bool, str]] = []


def scenario(name: str, ok: bool, detail: str = "") -> None:
    results.append((name, ok, detail))


def main() -> int:
    w3 = chain.get_w3()
    if not w3.is_connected():
        print("error: Anvil not reachable at", chain.RPC_URL)
        return 1

    addr = chain.deploy(w3)["address"]
    meta = chain.token_meta(w3, addr)
    scenario(
        "token-metadata",
        meta == {"name": "MockUSDC", "symbol": "mUSDC", "decimals": 6},
        str(meta),
    )

    again = chain.deploy(w3)
    scenario("deploy-idempotent", again["reused"] and again["address"] == addr, addr)

    if chain.balances(w3, addr)["persona_a"] < chain.PAYMENT_AMOUNT:
        chain.fund(w3, addr)

    before = chain.balances(w3, addr)
    pay = chain.pay(w3, addr)
    after = chain.balances(w3, addr)

    scenario("payment-confirmed", pay["status"] == 1, f"gas {pay['gas']}")
    scenario(
        "payment-amount",
        before["persona_a"] - after["persona_a"] == chain.PAYMENT_AMOUNT
        and after["persona_b"] - before["persona_b"] == chain.PAYMENT_AMOUNT,
        f"{chain.PAYMENT_AMOUNT / 1e6:.2f} mUSDC",
    )
    scenario(
        "supply-conserved",
        sum(before.values()) == sum(after.values()),
        f"total {sum(after.values())}",
    )

    width = max(len(n) for n, _, _ in results)
    for name, ok, detail in results:
        print(f"  {'PASS' if ok else 'FAIL'}  {name.ljust(width)}  {detail}")

    failed = [r for r in results if not r[1]]
    print()
    print(f"{len(results) - len(failed)}/{len(results)} scenarios passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
