#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/all-language-highlighting-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/all-language-highlighting.txt"
TARGETS_FILE="$ROOT_DIR/benchmarks/targets.env"
APP="$ROOT_DIR/.build/release/ArtisanApp"

source "$TARGETS_FILE"

fail() {
  echo "all-language highlighting benchmark check failed: $*" >&2
  exit 1
}

mkdir -p "$(dirname "$RESULT_FILE")"
"$ROOT_DIR/scripts/generate-language-benchmark-fixtures.sh" "$FIXTURE_DIR" >/dev/null

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-large-language-highlighting "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 300); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark large language highlighting mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark large language highlighting mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.large_language_highlighting=PASS$' "$RESULT_FILE" || fail "large language highlighting did not pass"

language_count="$(awk -F= '$1 == "benchmark.large_language.count" { print $2 }' "$RESULT_FILE")"
if [[ "$language_count" != "$ARTISAN_BENCH_LANGUAGE_HIGHLIGHT_EXPECTED_COUNT" ]]; then
  fail "expected $ARTISAN_BENCH_LANGUAGE_HIGHLIGHT_EXPECTED_COUNT languages, got ${language_count:-missing}"
fi

awk -F= -v max="$ARTISAN_BENCH_LANGUAGE_HIGHLIGHT_AVG_LINE_MS_MAX" '
  /^benchmark\.large_language\.[^.]+\.avg_line_ms=/ {
    seen += 1
    if ($2 >= max) {
      printf "language average %.4f must be < %.4f for %s\n", $2, max, $1 > "/dev/stderr"
      failed = 1
    }
  }
  END {
    if (seen == 0) {
      print "missing per-language average metrics" > "/dev/stderr"
      failed = 1
    }
    exit failed
  }
' "$RESULT_FILE" || fail "one or more language highlight averages exceeded target"

echo "all-language highlighting benchmark check passed"
