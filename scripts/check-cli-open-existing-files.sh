#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/.build/release/artisan"
APP_BUNDLE="$ROOT_DIR/.build/release/Artisan.app"
TEMP_DIRS=()

fail() {
  echo "cli open check failed: $*" >&2
  exit 1
}

stop_app() {
  pkill -x ArtisanApp >/dev/null 2>&1 || true
  rm -f "/tmp/artisan-$(id -u).sock"
}

cleanup() {
  stop_app
  if ((${#TEMP_DIRS[@]})); then
    rm -rf "${TEMP_DIRS[@]}"
    TEMP_DIRS=()
  fi
}

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/build-artisan-app.sh" >/dev/null
swift build -c release >/dev/null

stop_app
trap cleanup EXIT

fixture_dir="$(mktemp -d)"
TEMP_DIRS+=("$fixture_dir")
printf 'one\ntwo\nthree\n' >"$fixture_dir/open-target-a.txt"
printf 'other\n' >"$fixture_dir/open-target-b.txt"

help_output="$("$CLI" --help)"
[[ "$help_output" == *"usage: artisan [--wait] <existing-file[:line]>"* ]] || fail "--help did not include usage"
[[ "$help_output" == *"artisan Sources/App.swift:42"* ]] || fail "--help did not include line-target example"

command_help_output="$("$CLI" help)"
[[ "$command_help_output" == *"Line numbers are one-based"* ]] || fail "help command did not describe line numbers"

open_targets_output="$("$ROOT_DIR/.build/release/ArtisanApp" --benchmark-open-targets "$fixture_dir/open-target-a.txt" "$fixture_dir/open-target-b.txt")"
[[ "$open_targets_output" == *"benchmark.open_targets=PASS"* ]] || fail "open targets benchmark failed: $open_targets_output"

line_output="$("$CLI" "$fixture_dir/open-target-a.txt:2")"
[[ "$line_output" == "opened 1 file(s)" ]] || fail "line open returned: $line_output"
stop_app

single_output="$("$CLI" "$ROOT_DIR/README.md")"
[[ "$single_output" == "opened 1 file(s)" ]] || fail "single open returned: $single_output"
sleep 0.5
pgrep -f 'Artisan\.app/Contents/MacOS/ArtisanApp' >/dev/null || fail "CLI should launch the local app bundle"

multi_output="$("$CLI" "$ROOT_DIR/README.md" "$ROOT_DIR/CONTEXT.md")"
[[ "$multi_output" == "opened 2 file(s)" ]] || fail "multi open returned: $multi_output"

stop_app
cask_root="$(mktemp -d)"
bin_root="$(mktemp -d)"
TEMP_DIRS+=("$cask_root" "$bin_root")
mkdir -p "$cask_root/artisan/0.0.0"
install -m 0755 "$CLI" "$cask_root/artisan/0.0.0/artisan"
ln -s "$APP_BUNDLE" "$cask_root/artisan/0.0.0/Artisan.app"
ln -s "$cask_root/artisan/0.0.0/artisan" "$bin_root/artisan"
homebrew_output="$("$bin_root/artisan" "$ROOT_DIR/README.md")"
[[ "$homebrew_output" == "opened 1 file(s)" ]] || fail "homebrew-style symlink open returned: $homebrew_output"
stop_app

if "$CLI" "$ROOT_DIR/definitely-missing.ts" >/tmp/artisan-missing.out 2>/tmp/artisan-missing.err; then
  fail "missing file unexpectedly succeeded"
fi
rg -q 'file does not exist' /tmp/artisan-missing.err || fail "missing file error was not clear"

if "$CLI" "$fixture_dir/open-target-a.txt:0" >/tmp/artisan-invalid-line.out 2>/tmp/artisan-invalid-line.err; then
  fail "invalid line unexpectedly succeeded"
fi
rg -q 'invalid line' /tmp/artisan-invalid-line.err || fail "invalid line error was not clear"

if "$CLI" "$fixture_dir/open-target-a.txt:nope" >/tmp/artisan-invalid-line.out 2>/tmp/artisan-invalid-line.err; then
  fail "non-numeric line unexpectedly succeeded"
fi
rg -q 'invalid line' /tmp/artisan-invalid-line.err || fail "non-numeric line error was not clear"

if "$CLI" "$ROOT_DIR" >/tmp/artisan-dir.out 2>/tmp/artisan-dir.err; then
  fail "directory unexpectedly succeeded"
fi
rg -q 'file does not exist' /tmp/artisan-dir.err || fail "directory error was not clear"

echo "cli open check passed"
