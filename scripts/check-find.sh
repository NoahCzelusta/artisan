#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/find-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/find.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "find check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/find.txt" <<'TXT'
alpha beta
beta gamma
alpha beta alpha
TXT

LARGE_FIXTURE="$FIXTURE_DIR/find-large.ts"
: >"$LARGE_FIXTURE"
for index in $(seq 1 30000); do
  if [ "$index" = "100" ] || [ "$index" = "15000" ] || [ "$index" = "29950" ]; then
    printf 'line-%05d const needle = "%05d";\n' "$index" "$index" >>"$LARGE_FIXTURE"
  else
    printf 'line-%05d const value = "%05d";\n' "$index" "$index" >>"$LARGE_FIXTURE"
  fi
done

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-find "$FIXTURE_DIR/find.txt" "$LARGE_FIXTURE" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark find mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark find mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.find=PASS$' "$RESULT_FILE" || fail "find behavior did not pass"
rg -q '^benchmark.find_large=PASS$' "$RESULT_FILE" || fail "large find behavior did not pass"
echo "find check passed"
