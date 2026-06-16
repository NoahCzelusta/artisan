#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/selection-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/selection-model.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "selection model check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/selection.txt" <<'TXT'
alpha beta,gamma
  second_line words
last line
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-selection-model "$FIXTURE_DIR/selection.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark selection mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark selection mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.selection_model=PASS$' "$RESULT_FILE" || fail "selection model behavior did not pass"
echo "selection model check passed"
