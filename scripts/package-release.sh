#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${ARTISAN_RELEASE_VERSION:-}}"
ARCH="${ARTISAN_RELEASE_ARCH:-$(uname -m)}"
DIST_DIR="${ARTISAN_DIST_DIR:-$ROOT_DIR/dist}"
APP_NAME="Artisan"
CLI_NAME="artisan"
ARCHIVE_NAME="$APP_NAME-v$VERSION-macos-$ARCH.zip"
CASK_ARCHIVE_NAME="$APP_NAME-v#{version}-macos-$ARCH.zip"
ARCHIVE="$DIST_DIR/$ARCHIVE_NAME"
SHA_FILE="$ARCHIVE.sha256"
STAGE_ROOT="$DIST_DIR/stage"
STAGE="$STAGE_ROOT/$APP_NAME-v$VERSION-macos-$ARCH"
CASK_FILE="${ARTISAN_CASK_FILE:-$DIST_DIR/artisan.rb}"
REPOSITORY="${ARTISAN_RELEASE_REPOSITORY:-NoahCzelusta/artisan}"
if [[ -n "${ARTISAN_RELEASE_URL:-}" ]]; then
  RELEASE_URL="$ARTISAN_RELEASE_URL"
else
  RELEASE_URL="https://github.com/$REPOSITORY/releases/download/v#{version}/$CASK_ARCHIVE_NAME"
fi
BUILD_NUMBER="${ARTISAN_BUILD_NUMBER:-$(cd "$ROOT_DIR" && git rev-list --count HEAD 2>/dev/null || printf '1')}"
CODESIGN_IDENTITY="${ARTISAN_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${ARTISAN_NOTARY_KEYCHAIN_PROFILE:-}"
NOTARY_KEYCHAIN="${ARTISAN_NOTARY_KEYCHAIN:-}"

fail() {
  echo "package-release: $*" >&2
  exit 1
}

if [[ -z "$VERSION" ]]; then
  fail "usage: scripts/package-release.sh <version>"
fi

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  fail "version must look like 1.2.3, got $VERSION"
fi

cd "$ROOT_DIR"
if [[ "${ARTISAN_RELEASE_ALLOW_DIRTY:-0}" != "1" ]] && ! git diff --quiet --ignore-submodules --exit-code; then
  fail "worktree has unstaged changes; set ARTISAN_RELEASE_ALLOW_DIRTY=1 for a dry run"
fi
if [[ "${ARTISAN_RELEASE_ALLOW_DIRTY:-0}" != "1" ]] && [[ -n "$(git status --short --untracked-files=normal)" ]]; then
  fail "worktree has untracked files; set ARTISAN_RELEASE_ALLOW_DIRTY=1 for a dry run"
fi

mkdir -p "$DIST_DIR"
mkdir -p "$(dirname "$CASK_FILE")"
rm -rf "$STAGE"
mkdir -p "$STAGE"

APP_BUNDLE="$("$ROOT_DIR/scripts/build-artisan-app.sh" | tail -n 1)"
BUILD_BIN_DIR="$(swift build -c release --show-bin-path)"
CLI_BINARY="$BUILD_BIN_DIR/$CLI_NAME"

test -d "$APP_BUNDLE" || fail "expected app bundle at $APP_BUNDLE"
test -x "$CLI_BINARY" || fail "expected CLI binary at $CLI_BINARY"

ditto "$APP_BUNDLE" "$STAGE/$APP_NAME.app"
install -m 0755 "$CLI_BINARY" "$STAGE/$CLI_NAME"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$STAGE/$APP_NAME.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$STAGE/$APP_NAME.app/Contents/Info.plist"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$STAGE/$CLI_NAME"
  codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$STAGE/$APP_NAME.app"
else
  codesign --force --sign - "$STAGE/$CLI_NAME"
  codesign --force --deep --sign - "$STAGE/$APP_NAME.app"
fi

codesign --verify --deep --strict --verbose=2 "$STAGE/$APP_NAME.app"
codesign --verify --strict --verbose=2 "$STAGE/$CLI_NAME"

create_archive() {
  rm -f "$ARCHIVE" "$SHA_FILE"
  ditto -c -k --sequesterRsrc "$STAGE" "$ARCHIVE"
}

create_archive

if [[ -n "$NOTARY_PROFILE" ]]; then
  notary_args=(submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait)
  if [[ -n "$NOTARY_KEYCHAIN" ]]; then
    notary_args+=(--keychain "$NOTARY_KEYCHAIN")
  fi
  xcrun notarytool "${notary_args[@]}"
  xcrun stapler staple "$STAGE/$APP_NAME.app"
  xcrun stapler validate "$STAGE/$APP_NAME.app"
  create_archive
fi

SHA256="$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')"
printf '%s  %s\n' "$SHA256" "$(basename "$ARCHIVE")" >"$SHA_FILE"

cat >"$CASK_FILE" <<RUBY
cask "artisan" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$RELEASE_URL"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/$REPOSITORY"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
RUBY

echo "archive=$ARCHIVE"
echo "sha256=$SHA_FILE"
echo "cask=$CASK_FILE"
if [[ -z "$CODESIGN_IDENTITY" ]]; then
  echo "warning=ad-hoc signed package; set ARTISAN_CODESIGN_IDENTITY for trusted distribution"
fi
if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "warning=not notarized; set ARTISAN_NOTARY_KEYCHAIN_PROFILE for trusted distribution"
fi
