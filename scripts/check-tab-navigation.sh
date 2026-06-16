#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/tab-navigation-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/tab-navigation.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "tab navigation check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
for index in $(seq 0 11); do
  printf 'tab %02d\nline two\n' "$index" >"$(printf '%s/tab-%02d.txt' "$FIXTURE_DIR" "$index")"
done

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-tab-navigation "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark tab navigation mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark tab navigation mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.tab_navigation=PASS$' "$RESULT_FILE" || fail "tab navigation behavior did not pass"
echo "tab navigation check passed"
