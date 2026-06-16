#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS_FILE="$ROOT_DIR/benchmarks/targets.env"
FIXTURE_DIR="$ROOT_DIR/.scratch/benchmark-fixtures"
RESULTS_FILE="$ROOT_DIR/.scratch/benchmark-results/latest.txt"

source "$TARGETS_FILE"

mkdir -p "$(dirname "$RESULTS_FILE")"

"$ROOT_DIR/scripts/generate-benchmark-fixtures.sh" "$FIXTURE_DIR" >/dev/null

cd "$ROOT_DIR"
swift build -c release >/dev/null

APP="$ROOT_DIR/.build/release/ArtisanPrototypeApp"
CLI="$ROOT_DIR/.build/release/artisan-proto"
FIXTURE="$FIXTURE_DIR/large.ts"

cleanup() {
  pkill -f "$ROOT_DIR/.build/release/ArtisanPrototypeApp" >/dev/null 2>&1 || true
  pkill -f "$ROOT_DIR/.build/release/artisan-proto" >/dev/null 2>&1 || true
  rm -f "/tmp/artisan-prototype-$(id -u).sock"
}

cold_open_ms() {
  local stderr_file
  local start
  local end
  local pid
  local ticks=0
  stderr_file="$(mktemp)"
  start="$(perl -MTime::HiRes=time -e 'printf "%.6f", time')"
  "$CLI" "$FIXTURE" >/dev/null 2>"$stderr_file" &
  pid="$!"

  while kill -0 "$pid" >/dev/null 2>&1; do
    if [[ "$ticks" -ge 50 ]]; then
      kill "$pid" >/dev/null 2>&1 || true
      cleanup
      cat "$stderr_file" >&2 || true
      rm -f "$stderr_file"
      fail "cold CLI open timed out"
    fi
    sleep 0.1
    ticks=$((ticks + 1))
  done

  if ! wait "$pid"; then
    cat "$stderr_file" >&2 || true
    rm -f "$stderr_file"
    fail "cold CLI open failed"
  fi

  end="$(perl -MTime::HiRes=time -e 'printf "%.6f", time')"
  rm -f "$stderr_file"
  perl -e 'printf "%.0f\n", (($ARGV[1] - $ARGV[0]) * 1000)' "$start" "$end"
}

metric() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print $2; found = 1 } END { if (!found) exit 1 }' "$RESULTS_FILE"
}

fail() {
  echo "benchmark failure: $*" >&2
  exit 1
}

assert_lt() {
  local key="$1"
  local max="$2"
  local value
  value="$(metric "$key")"
  awk -v value="$value" -v max="$max" 'BEGIN { exit !(value < max) }' || fail "$key=$value must be < $max"
}

assert_le() {
  local key="$1"
  local max="$2"
  local value
  value="$(metric "$key")"
  awk -v value="$value" -v max="$max" 'BEGIN { exit !(value <= max) }' || fail "$key=$value must be <= $max"
}

assert_ge() {
  local key="$1"
  local min="$2"
  local value
  value="$(metric "$key")"
  awk -v value="$value" -v min="$min" 'BEGIN { exit !(value >= min) }' || fail "$key=$value must be >= $min"
}

cleanup
"$APP" --benchmark-scroll "$FIXTURE" | tee "$RESULTS_FILE"

assert_lt benchmark.open_ms "$ARTISAN_BENCH_APP_OPEN_MS_MAX"
assert_lt benchmark.immediate_bottom_render_ms "$ARTISAN_BENCH_IMMEDIATE_BOTTOM_RENDER_MS_MAX"
assert_ge benchmark.immediate_bottom_non_empty_lines "$ARTISAN_BENCH_IMMEDIATE_BOTTOM_NON_EMPTY_LINES_MIN"
assert_ge benchmark.index_on_scroll_count "$ARTISAN_BENCH_INDEX_ON_SCROLL_COUNT_MIN"
assert_le benchmark.index_on_draw_count "$ARTISAN_BENCH_INDEX_ON_DRAW_COUNT_MAX"
assert_lt benchmark.full_index_ms "$ARTISAN_BENCH_FULL_INDEX_MS_MAX"
assert_lt benchmark.scroll_avg_step_ms "$ARTISAN_BENCH_SCROLL_AVG_STEP_MS_MAX"
assert_lt benchmark.navigation_avg_move_ms "$ARTISAN_BENCH_NAVIGATION_AVG_MOVE_MS_MAX"
assert_lt benchmark.highlight_avg_line_ms "$ARTISAN_BENCH_HIGHLIGHT_AVG_LINE_MS_MAX"
assert_lt benchmark.insert_avg_char_ms "$ARTISAN_BENCH_INSERT_AVG_CHAR_MS_MAX"
assert_lt benchmark.delete_avg_char_ms "$ARTISAN_BENCH_DELETE_AVG_CHAR_MS_MAX"
assert_lt benchmark.newline_avg_insert_ms "$ARTISAN_BENCH_NEWLINE_AVG_INSERT_MS_MAX"
assert_lt benchmark.paste_1kb_ms "$ARTISAN_BENCH_PASTE_1KB_MS_MAX"

# Warm the executable/page cache once, then measure controlled cold app launches.
cleanup
"$CLI" "$FIXTURE" >/dev/null
cleanup

cold_results=()
for _ in 1 2 3 4 5; do
  cleanup
  sleep 0.1
  ms="$(cold_open_ms)"
  cold_results+=("$ms")
done
cleanup

printf 'benchmark.cold_cli_open_ms_runs=%s\n' "${cold_results[*]}" | tee -a "$RESULTS_FILE"
for ms in "${cold_results[@]}"; do
  awk -v value="$ms" -v max="$ARTISAN_BENCH_COLD_CLI_OPEN_MS_MAX" 'BEGIN { exit !(value < max) }' \
    || fail "cold_cli_open_ms=$ms must be < $ARTISAN_BENCH_COLD_CLI_OPEN_MS_MAX"
done

echo "benchmark result: PASS"
