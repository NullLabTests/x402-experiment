#!/usr/bin/env bash
# Render PNG screenshots with the cached Playwright Chromium (headless).
# usage: shot.sh <url|file> <out.png> <WxH> [extra chromium args...]
set -eu
CHROME="${CHROME:-/home/illy/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome}"
URL="$1"; OUT="$2"; SIZE="$3"; shift 3
mkdir -p "$(dirname "$OUT")"
"$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size="$SIZE" \
  --virtual-time-budget=9000 \
  --screenshot="$OUT" "$URL" "$@" 2>/dev/null
ls -la "$OUT"
