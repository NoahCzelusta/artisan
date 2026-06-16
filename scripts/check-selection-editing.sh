#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/selection-editing-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/selection-editing.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "selection editing check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/selection-editing.txt" <<'TXT'
one two
three four
five six
TXT

LARGE_FIXTURE="$FIXTURE_DIR/selection-editing-large.txt"
: >"$LARGE_FIXTURE"
for index in $(seq 1 30000); do
  printf 'line-%05d const value = "%05d";\n' "$index" "$index" >>"$LARGE_FIXTURE"
done

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-selection-editing "$FIXTURE_DIR/selection-editing.txt" "$LARGE_FIXTURE" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark selection editing mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark selection editing mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.selection_editing=PASS$' "$RESULT_FILE" || fail "selection editing behavior did not pass"
rg -q '^benchmark.selection_editing_large_select_all=PASS$' "$RESULT_FILE" || fail "large-file select-all behavior did not pass"
echo "selection editing check passed"
