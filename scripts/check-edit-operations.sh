#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/edit-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/edit-operations.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "edit operations check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/basic.txt" <<'TXT'
alpha
bravo
charlie
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-edit-operations "$FIXTURE_DIR/basic.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark edit mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark edit mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.edit_operations=PASS$' "$RESULT_FILE" || fail "edit operations did not pass"
echo "edit operations check passed"
