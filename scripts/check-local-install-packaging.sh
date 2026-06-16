#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/local-install-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/local-install.txt"

fail() {
  echo "local install packaging check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/install-smoke.txt" <<'TXT'
local install smoke
TXT

INSTALL_ROOT="$(mktemp -d)"
BIN_DIR="$(mktemp -d)"
trap 'rm -rf "$INSTALL_ROOT" "$BIN_DIR"' EXIT

cd "$ROOT_DIR"

ARTISAN_INSTALL_ROOT="$INSTALL_ROOT/share/artisan" \
ARTISAN_BIN_DIR="$BIN_DIR" \
  scripts/install-local.sh >"$RESULT_FILE"

test -d "$INSTALL_ROOT/share/artisan/Artisan.app" || fail "installed app bundle missing"
test -x "$INSTALL_ROOT/share/artisan/artisan" || fail "installed CLI binary missing"
test -x "$BIN_DIR/artisan" || fail "installed PATH wrapper missing"

"$BIN_DIR/artisan" "$FIXTURE_DIR/does-not-exist.txt" >/dev/null 2>&1 && fail "missing file should be rejected"

ARTISAN_INSTALL_ROOT="$INSTALL_ROOT/share/artisan" \
ARTISAN_BIN_DIR="$BIN_DIR" \
  scripts/uninstall-local.sh >>"$RESULT_FILE"

test ! -e "$INSTALL_ROOT/share/artisan/Artisan.app" || fail "uninstall left app bundle"
test ! -e "$INSTALL_ROOT/share/artisan/artisan" || fail "uninstall left CLI binary"
test ! -e "$BIN_DIR/artisan" || fail "uninstall left PATH wrapper"

cat "$RESULT_FILE"
echo "local install packaging check passed"
