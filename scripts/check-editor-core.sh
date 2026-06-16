#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/editor-core-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/editor-core.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "editor core check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
: >"$FIXTURE_DIR/large-core.txt"
for index in $(seq 1 30000); do
  printf 'line-%05d value %05d\n' "$index" "$index" >>"$FIXTURE_DIR/large-core.txt"
done

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-editor-core "$FIXTURE_DIR/large-core.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark editor core mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark editor core mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.editor_core=PASS$' "$RESULT_FILE" || fail "editor core large edit behavior did not pass"

scripts/check-selection-editing.sh >/dev/null
scripts/check-undo-redo.sh >/dev/null
scripts/check-save-operations.sh >/dev/null
scripts/check-language-registry.sh >/dev/null
scripts/check-cli-open-existing-files.sh >/dev/null

echo "editor core check passed"
