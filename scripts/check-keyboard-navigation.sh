#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/navigation-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/keyboard-navigation.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "keyboard navigation check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/nav.txt" <<'TXT'
alpha beta,gamma
  second_line words
last line
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-keyboard-navigation "$FIXTURE_DIR/nav.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark keyboard-navigation mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark keyboard-navigation mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.keyboard_navigation=PASS$' "$RESULT_FILE" || fail "keyboard navigation behavior did not pass"
rg -q 'Home' "$ROOT_DIR/docs/keyboard-navigation.md" || fail "Home behavior must be documented"
rg -q 'End' "$ROOT_DIR/docs/keyboard-navigation.md" || fail "End behavior must be documented"
echo "keyboard navigation check passed"
