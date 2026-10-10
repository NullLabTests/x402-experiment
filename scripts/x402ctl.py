#!/usr/bin/env python3
"""x402 paper-trading control CLI.

Thin wrapper over facilitator.chain so the Makefile and scripts can drive
the local experiment without inline Python. Paper tokens only, localhost only.

usage: x402ctl.py {status|deploy|fund|flow}
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from facilitator import chain  # noqa: E402


def _print(obj) -> None:
    print(json.dumps(obj, indent=2))


def cmd_status() -> int:
    _print(chain.status())
    return 0


def cmd_deploy() -> int:
    w3 = chain.get_w3()
    if not w3.is_connected():
        print("error: Anvil not reachable at", chain.RPC_URL, file=sys.stderr)
        return 1
    _print(chain.deploy(w3))
    return 0


def cmd_fund() -> int:
    w3 = chain.get_w3()
    addr = chain.contract_address(w3)
    if not addr:
        print("error: MockUSDC not deployed (run `x402ctl.py deploy`)", file=sys.stderr)
        return 1
    res = chain.fund(w3, addr)
    res["balances"] = chain.balances(w3, addr)
    _print(res)
    return 0


def cmd_flow() -> int:
    w3 = chain.get_w3()
    if not w3.is_connected():
        print("error: Anvil not reachable at", chain.RPC_URL, file=sys.stderr)
        return 1
    deploy_res = chain.deploy(w3)
    addr = deploy_res["address"]
    if chain.balances(w3, addr)["persona_a"] < chain.PAYMENT_AMOUNT:
        chain.fund(w3, addr)
    before = chain.balances(w3, addr)
    pay_res = chain.pay(w3, addr)
    after = chain.balances(w3, addr)
    _print(
        {
            "contract": addr,
            "payment": pay_res,
            "balances_before": before,
            "balances_after": after,
            "ok": pay_res["status"] == 1,
        }
    )
    return 0 if pay_res["status"] == 1 else 1


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "status"
    table = {
        "status": cmd_status,
        "deploy": cmd_deploy,
        "fund": cmd_fund,
        "flow": cmd_flow,
    }
    if cmd not in table:
        print(__doc__, file=sys.stderr)
        return 2
    return table[cmd]()


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
