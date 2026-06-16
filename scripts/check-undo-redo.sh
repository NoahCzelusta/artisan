#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/undo-redo-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/undo-redo.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "undo redo check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/undo-redo.txt" <<'TXT'
alpha beta
gamma delta
epsilon zeta
TXT

LARGE_FIXTURE="$FIXTURE_DIR/undo-redo-large.txt"
: >"$LARGE_FIXTURE"
for index in $(seq 1 30000); do
  printf 'line-%05d const value = "%05d";\n' "$index" "$index" >>"$LARGE_FIXTURE"
done

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-undo-redo "$FIXTURE_DIR/undo-redo.txt" "$LARGE_FIXTURE" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark undo redo mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark undo redo mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.undo_redo=PASS$' "$RESULT_FILE" || fail "undo redo behavior did not pass"
rg -q '^benchmark.undo_redo_large_bottom=PASS$' "$RESULT_FILE" || fail "large-file bottom undo redo behavior did not pass"
echo "undo redo check passed"
