#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/.build/release/artisan"
WAIT_OUT="$ROOT_DIR/.scratch/benchmark-results/wait.out"
WAIT_ERR="$ROOT_DIR/.scratch/benchmark-results/wait.err"

fail() {
  echo "cli wait check failed: $*" >&2
  exit 1
}

cleanup() {
  pkill -x ArtisanApp >/dev/null 2>&1 || true
  rm -f "/tmp/artisan-$(id -u).sock"
}

quit_app() {
  osascript -e 'tell application id "com.noahczelusta.Artisan" to quit' >/dev/null 2>&1 \
    || osascript -e 'tell application "Artisan" to quit' >/dev/null 2>&1 \
    || pkill -x ArtisanApp >/dev/null 2>&1 \
    || true
}

mkdir -p "$(dirname "$WAIT_OUT")"
cd "$ROOT_DIR"
"$ROOT_DIR/scripts/build-artisan-app.sh" >/dev/null

cleanup
trap cleanup EXIT

if "$CLI" --wait "$ROOT_DIR/definitely-missing.ts" >/tmp/artisan-wait-missing.out 2>/tmp/artisan-wait-missing.err; then
  fail "missing file unexpectedly succeeded"
fi
rg -q 'file does not exist' /tmp/artisan-wait-missing.err || fail "missing file error was not clear"

"$CLI" --wait "$ROOT_DIR/README.md" >"$WAIT_OUT" 2>"$WAIT_ERR" &
wait_pid="$!"

sleep 1
kill -0 "$wait_pid" >/dev/null 2>&1 || fail "--wait exited before the tab or app closed"

quit_app

for _ in $(seq 1 50); do
  if ! kill -0 "$wait_pid" >/dev/null 2>&1; then
    wait "$wait_pid" || fail "--wait exited non-zero after app quit"
    echo "cli wait check passed"
    exit 0
  fi
  sleep 0.1
done

kill "$wait_pid" >/dev/null 2>&1 || true
fail "--wait did not resume after app quit"
