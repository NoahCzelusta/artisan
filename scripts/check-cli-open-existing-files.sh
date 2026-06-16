#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/.build/release/artisan"

fail() {
  echo "cli open check failed: $*" >&2
  exit 1
}

cleanup() {
  pkill -x ArtisanApp >/dev/null 2>&1 || true
  rm -f "/tmp/artisan-$(id -u).sock"
}

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/build-artisan-app.sh" >/dev/null

cleanup
trap cleanup EXIT

single_output="$("$CLI" "$ROOT_DIR/README.md")"
[[ "$single_output" == "opened 1 file(s)" ]] || fail "single open returned: $single_output"
sleep 0.5
pgrep -f 'Artisan\.app/Contents/MacOS/ArtisanApp' >/dev/null || fail "CLI should launch the local app bundle"

multi_output="$("$CLI" "$ROOT_DIR/README.md" "$ROOT_DIR/CONTEXT.md")"
[[ "$multi_output" == "opened 2 file(s)" ]] || fail "multi open returned: $multi_output"

if "$CLI" "$ROOT_DIR/definitely-missing.ts" >/tmp/artisan-missing.out 2>/tmp/artisan-missing.err; then
  fail "missing file unexpectedly succeeded"
fi
rg -q 'file does not exist' /tmp/artisan-missing.err || fail "missing file error was not clear"

if "$CLI" "$ROOT_DIR" >/tmp/artisan-dir.out 2>/tmp/artisan-dir.err; then
  fail "directory unexpectedly succeeded"
fi
rg -q 'file does not exist' /tmp/artisan-dir.err || fail "directory error was not clear"

echo "cli open check passed"
