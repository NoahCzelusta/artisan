#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/disk-change-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/disk-change-save.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "disk change save check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
printf 'original\n' >"$FIXTURE_DIR/cancel.txt"
printf 'original\n' >"$FIXTURE_DIR/reload.txt"
printf 'original\n' >"$FIXTURE_DIR/save-anyway.txt"

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-disk-change-save "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark disk-change mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark disk-change mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.disk_change_save=PASS$' "$RESULT_FILE" || fail "disk-change save behavior did not pass"
[[ "$(cat "$FIXTURE_DIR/cancel.txt")" == "external" ]] || fail "cancel branch should leave external disk contents"
[[ "$(cat "$FIXTURE_DIR/reload.txt")" == "external" ]] || fail "reload branch should keep external disk contents"
[[ "$(cat "$FIXTURE_DIR/save-anyway.txt")" == "local!original" ]] || fail "save-anyway branch should overwrite with local edit"
echo "disk change save check passed"
