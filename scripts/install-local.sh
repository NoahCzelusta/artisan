#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
INSTALL_ROOT="${ARTISAN_INSTALL_ROOT:-$HOME/.local/share/artisan}"
BIN_DIR="${ARTISAN_BIN_DIR:-$HOME/.local/bin}"
APP_NAME="Artisan"
CLI_NAME="artisan"
WRAPPER="$BIN_DIR/$CLI_NAME"
WRAPPER_MARKER="Installed by Artisan local installer"
WRAPPER_CLI="$INSTALL_ROOT/$CLI_NAME"

fail() {
  echo "install-local: $*" >&2
  exit 1
}

mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

APP_BUNDLE="$("$ROOT_DIR/scripts/build-artisan-app.sh" | tail -n 1)"
BUILD_BIN_DIR="$(cd "$ROOT_DIR" && swift build -c "$CONFIGURATION" --show-bin-path)"
CLI_BINARY="$BUILD_BIN_DIR/$CLI_NAME"

test -d "$APP_BUNDLE" || fail "expected app bundle at $APP_BUNDLE"
test -x "$CLI_BINARY" || fail "expected CLI binary at $CLI_BINARY"

if [[ -e "$WRAPPER" ]] && ! grep -Fq "$WRAPPER_MARKER" "$WRAPPER"; then
  fail "refusing to overwrite existing $WRAPPER"
fi

rm -rf "$INSTALL_ROOT/$APP_NAME.app"
ditto "$APP_BUNDLE" "$INSTALL_ROOT/$APP_NAME.app"
install -m 0755 "$CLI_BINARY" "$INSTALL_ROOT/$CLI_NAME"

printf '#!/usr/bin/env bash\n# %s\n# Artisan CLI: %s\nexec %q "$@"\n' \
  "$WRAPPER_MARKER" \
  "$WRAPPER_CLI" \
  "$WRAPPER_CLI" >"$WRAPPER"
chmod 0755 "$WRAPPER"

echo "Installed $APP_NAME.app to $INSTALL_ROOT/$APP_NAME.app"
echo "Installed $CLI_NAME wrapper to $WRAPPER"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Add $BIN_DIR to PATH to run: $CLI_NAME <existing-file>"
fi
