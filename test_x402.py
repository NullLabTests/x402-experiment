#!/usr/bin/env python3
"""x402 integration test.

Assumes the local stack is running (see `make setup` / `scripts/stack.sh start`).
Exercises the facilitator HTTP API and the paper payment lifecycle end to end.

Exit code 0 = all checks passed.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CFG = json.loads((ROOT / "config.json").read_text())
FACILITATOR = CFG["facilitator_url"]

failures = 0


def http(method: str, path: str, body: dict | None = None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        FACILITATOR + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read().decode() or "{}")


def check(name: str, ok: bool, detail: str = "") -> None:
    global failures
    mark = "PASS" if ok else "FAIL"
    if not ok:
        failures += 1
    print(f"[{mark}] {name}" + (f" — {detail}" if detail else ""))


def main() -> int:
    code, body = http("GET", "/verify")
    check("verify", code == 200 and body.get("status") == "ok", f"HTTP {code} {body}")

    code, body = http("POST", "/settle", {"payment_id": "itest"})
    check("settle", code == 200 and body.get("status") == "settled", f"HTTP {code} {body}")

    code, body = http("GET", "/.well-known/agent.json")
    check("a2a agent card", code == 200 and bool(body.get("skills")), f"HTTP {code}")

    code, dep = http("POST", "/api/deploy")
    check("deploy", code == 200 and dep.get("deployed"), dep.get("address", str(dep)))

    code, fund = http("POST", "/api/fund")
    check("fund", code == 200 and fund.get("status") == 1, f"tx {fund.get('hash', '')[:12]}")

    code, flow = http("POST", "/api/flow", {"payment_id": "itest-flow"})
    steps = flow.get("steps", [])
    ok_steps = len(steps) == 3 and all(
        (s.get("http", 200) < 400) and (s.get("status", 1) == 1) for s in steps
    )
    delta_a = flow.get("balances_before", {}).get("persona_a", 0) - flow.get(
        "balances_after", {}
    ).get("persona_a", 0)
    delta_b = flow.get("balances_after", {}).get("persona_b", 0) - flow.get(
        "balances_before", {}
    ).get("persona_b", 0)
    check("lifecycle steps", ok_steps, f"{len(steps)} steps")
    check("payment moved funds", delta_a == delta_b > 0, f"A -{delta_a}, B +{delta_b}")

    code, checks = http("GET", "/api/h1h5")
    all_pass = all(c["status"] == "PASS" for c in checks.get("checks", []))
    check("H1-H5", code == 200 and all_pass, ", ".join(f"{c['id']}:{c['status']}" for c in checks.get("checks", [])))

    print()
    if failures:
        print(f"{failures} check(s) failed")
        return 1
    print("all integration checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
