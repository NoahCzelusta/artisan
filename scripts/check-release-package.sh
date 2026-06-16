#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${ARTISAN_RELEASE_VERSION:-0.0.0-ci}"
ARCH="${ARTISAN_RELEASE_ARCH:-$(uname -m)}"
DIST_DIR="${ARTISAN_DIST_DIR:-$ROOT_DIR/.scratch/release-package-fixtures/dist}"
ARCHIVE="$DIST_DIR/Artisan-v$VERSION-macos-$ARCH.zip"
SHA_FILE="$ARCHIVE.sha256"
CASK_FILE="$DIST_DIR/artisan.rb"

fail() {
  echo "release package check failed: $*" >&2
  exit 1
}

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ARTISAN_RELEASE_ALLOW_DIRTY=1 \
ARTISAN_DIST_DIR="$DIST_DIR" \
  "$ROOT_DIR/scripts/package-release.sh" "$VERSION"

test -f "$ARCHIVE" || fail "missing archive $ARCHIVE"
test -f "$SHA_FILE" || fail "missing checksum $SHA_FILE"
test -f "$CASK_FILE" || fail "missing generated cask $CASK_FILE"

(cd "$DIST_DIR" && shasum -a 256 -c "$(basename "$SHA_FILE")")
unzip -l "$ARCHIVE" | rg -q 'Artisan\.app/Contents/Info\.plist' || fail "archive missing app bundle"
unzip -l "$ARCHIVE" | rg -q '[[:space:]]artisan$' || fail "archive missing CLI binary"
unzip -p "$ARCHIVE" "Artisan.app/Contents/Info.plist" | plutil -lint - >/dev/null || fail "archived Info.plist is invalid"
ruby -c "$CASK_FILE" >/dev/null || fail "generated cask is not valid Ruby"
rg -q "version \"$VERSION\"" "$CASK_FILE" || fail "generated cask has wrong version"
rg -F -q 'v#{version}' "$CASK_FILE" || fail "generated cask URL must interpolate version"
rg -F -q 'depends_on macos: :sonoma' "$CASK_FILE" || fail "generated cask must use modern macOS dependency syntax"
rg -q 'app "Artisan\.app"' "$CASK_FILE" || fail "generated cask missing app stanza"
rg -q 'binary "artisan"' "$CASK_FILE" || fail "generated cask missing binary stanza"

echo "release package check passed"
