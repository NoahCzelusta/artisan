#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="${ARTISAN_INSTALL_ROOT:-$HOME/.local/share/artisan}"
BIN_DIR="${ARTISAN_BIN_DIR:-$HOME/.local/bin}"
APP_NAME="Artisan"
CLI_NAME="artisan"
WRAPPER="$BIN_DIR/$CLI_NAME"
WRAPPER_MARKER="Installed by Artisan local installer"
WRAPPER_CLI="$INSTALL_ROOT/$CLI_NAME"

rm -rf "$INSTALL_ROOT/$APP_NAME.app"
rm -f "$INSTALL_ROOT/$CLI_NAME"

if [[ -e "$WRAPPER" ]]; then
  if grep -Fq "$WRAPPER_MARKER" "$WRAPPER" && grep -Fq "# Artisan CLI: $WRAPPER_CLI" "$WRAPPER"; then
    rm -f "$WRAPPER"
  else
    echo "uninstall-local: preserved unrelated $WRAPPER" >&2
  fi
fi

rmdir "$INSTALL_ROOT" >/dev/null 2>&1 || true

echo "Removed Artisan local install from $INSTALL_ROOT"
