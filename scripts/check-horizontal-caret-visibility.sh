#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/horizontal-caret-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/horizontal-caret-visibility.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "horizontal caret visibility check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
perl -e 'print "const value = \"" . ("artisan-" x 140) . "\";\nnext line\n"' >"$FIXTURE_DIR/long-line.ts"

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-horizontal-caret-visibility "$FIXTURE_DIR/long-line.ts" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark horizontal caret visibility mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark horizontal caret visibility mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.horizontal_caret_visibility=PASS$' "$RESULT_FILE" || fail "horizontal caret visibility behavior did not pass"
echo "horizontal caret visibility check passed"
