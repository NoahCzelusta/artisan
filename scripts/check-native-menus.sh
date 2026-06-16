#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/native-menu-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/native-menus.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "native menus check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/native-menus.txt" <<'TXT'
alpha beta
gamma delta
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-native-menus "$FIXTURE_DIR/native-menus.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark native menus mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark native menus mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.native_menus=PASS$' "$RESULT_FILE" || fail "native menu behavior did not pass"
echo "native menus check passed"
