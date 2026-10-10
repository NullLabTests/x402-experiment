#!/usr/bin/env bash
# Chaos-mode verification for the facilitator.
# Spins up a throwaway facilitator on port 8001 with chaos env vars and
# checks the failure modes. Exit 0 = all chaos behaviours correct.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT=8001
fails=0

run_case() {
  local name="$1" envvars="$2" method="$3" path="$4" want="$5"
  env $envvars python3 -m uvicorn facilitator.app:app --host 127.0.0.1 --port "$PORT" \
    > /tmp/opencode/chaos.log 2>&1 < /dev/null &
  local pid=$!
  for _ in $(seq 1 20); do
    curl -s -o /dev/null "http://127.0.0.1:${PORT}/verify" && break
    sleep 0.3
  done
  local code
  if [ "$method" = "POST" ]; then
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:${PORT}${path}" \
      -H 'Content-Type: application/json' -d '{"payment_id":"chaos"}')
  else
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}${path}")
  fi
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  if [ "$code" = "$want" ]; then
    echo "  PASS  ${name} (HTTP ${code})"
  else
    echo "  FAIL  ${name} (expected ${want}, got ${code})"
    fails=$((fails + 1))
  fi
}

echo "chaos scenarios:"
run_case "reject-valid"    "CHAOS_REJECT_VALID=true"  GET  /verify 403
run_case "settle-fail"     "CHAOS_SETTLE_FAIL=true"   POST /settle 500
run_case "healthy-baseline" ""                         GET  /verify 200

echo
if [ "$fails" -gt 0 ]; then
  echo "$fails chaos scenario(s) failed"
  exit 1
fi
echo "all chaos scenarios passed"
