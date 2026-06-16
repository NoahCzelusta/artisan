#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/save-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/save-operations.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "save operations check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
printf 'hello\nsecond\n' >"$FIXTURE_DIR/lf-final.txt"
printf 'one\r\ntwo\r\n' >"$FIXTURE_DIR/crlf-final.txt"
printf 'tail' >"$FIXTURE_DIR/no-final.txt"

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-save-operations "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark save mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark save mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.save_operations=PASS$' "$RESULT_FILE" || fail "save operations did not pass"
[[ "$(cat "$FIXTURE_DIR/lf-final.txt")"$'\n' == $'hello!\nsecond\n' ]] || fail "LF final-newline fixture mismatch"
python3 - "$FIXTURE_DIR/crlf-final.txt" <<'PY' || exit 1
from pathlib import Path
import sys
expected = b"one!\r\ntwo\r\n"
actual = Path(sys.argv[1]).read_bytes()
if actual != expected:
    print(f"CRLF fixture mismatch: {actual!r}", file=sys.stderr)
    sys.exit(1)
PY
[[ "$(cat "$FIXTURE_DIR/no-final.txt")" == "tail!" ]] || fail "no-final-newline fixture mismatch"
echo "save operations check passed"
