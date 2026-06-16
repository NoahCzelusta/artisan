#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/benchmark-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/plain-text-rendering.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "plain text rendering check failed: $*" >&2
  exit 1
}

mkdir -p "$(dirname "$RESULT_FILE")"
"$ROOT_DIR/scripts/generate-benchmark-fixtures.sh" "$FIXTURE_DIR" >/dev/null

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-highlight-mode "$FIXTURE_DIR/large.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark highlight mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark highlight mode timed out"
fi

cat "$RESULT_FILE"

multi_segment_lines="$(awk -F= '$1 == "benchmark.highlight_multi_segment_lines" { print $2 }' "$RESULT_FILE")"
if [[ -z "$multi_segment_lines" ]]; then
  fail "missing benchmark.highlight_multi_segment_lines"
fi

if [[ "$multi_segment_lines" != "0" ]]; then
  fail "large.txt should render as plain text, got $multi_segment_lines multi-segment lines"
fi

echo "plain text rendering check passed"
