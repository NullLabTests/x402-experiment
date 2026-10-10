#!/usr/bin/env bash
# Dev helper: start/stop the local Anvil + facilitator stack for the GUI.
# All value is worthless paper tokens on localhost (chain 31337).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG=/tmp/opencode
mkdir -p "$LOG"

kill_port() {
  local port="$1"
  local pids
  pids="$(ss -ltnp 2>/dev/null | grep ":${port} " | grep -oP 'pid=\K[0-9]+' | sort -u)"
  for p in $pids; do
    [ "$p" = "$$" ] && continue
    kill "$p" 2>/dev/null || true
  done
}

case "${1:-start}" in
  start)
    kill_port 8545; kill_port 8000
    sleep 1
    export PATH="/home/illy/.foundry/bin:$PATH"
    setsid anvil --chain-id 31337 --port 8545 -a 10 --silent \
      > "$LOG/anvil.log" 2>&1 < /dev/null &
    sleep 3
    cd "$ROOT"
    setsid python3 -m uvicorn facilitator.app:app --host 127.0.0.1 --port 8000 \
      > "$LOG/facilitator.log" 2>&1 < /dev/null &
    sleep 4
    echo "anvil+rpc:"
    ss -ltn 2>/dev/null | grep -E ':(8545|8000) ' || echo "  (none listening yet)"
    ;;
  stop)
    kill_port 8545; kill_port 8000
    echo "stopped."
    ;;
  *)
    echo "usage: $0 {start|stop}"; exit 1;;
esac
