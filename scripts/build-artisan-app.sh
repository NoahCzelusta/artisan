#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Artisan"
EXECUTABLE_NAME="ArtisanApp"
BUNDLE_ID="com.noahczelusta.Artisan"
MIN_SYSTEM_VERSION="14.0"

BUILD_PRODUCTS_DIR="$ROOT_DIR/.build/$CONFIGURATION"
APP_BUNDLE="$BUILD_PRODUCTS_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

BUILD_BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_DIR/$EXECUTABLE_NAME"
if [[ ! -x "$BUILD_BINARY" ]]; then
  echo "build-artisan-app: expected executable at $BUILD_BINARY" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Text and Source Files</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.text</string>
        <string>public.plain-text</string>
        <string>public.source-code</string>
        <string>public.shell-script</string>
        <string>public.swift-source</string>
        <string>public.python-script</string>
        <string>public.ruby-script</string>
        <string>public.php-script</string>
        <string>public.json</string>
        <string>public.yaml</string>
        <string>public.xml</string>
        <string>public.html</string>
        <string>public.css</string>
        <string>net.daringfireball.markdown</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>txt</string>
        <string>text</string>
        <string>md</string>
        <string>markdown</string>
        <string>ts</string>
        <string>tsx</string>
        <string>js</string>
        <string>jsx</string>
        <string>mjs</string>
        <string>cjs</string>
        <string>py</string>
        <string>java</string>
        <string>c</string>
        <string>h</string>
        <string>cpp</string>
        <string>cc</string>
        <string>cxx</string>
        <string>hpp</string>
        <string>cs</string>
        <string>go</string>
        <string>rs</string>
        <string>php</string>
        <string>rb</string>
        <string>swift</string>
        <string>kt</string>
        <string>kts</string>
        <string>sql</string>
        <string>html</string>
        <string>htm</string>
        <string>css</string>
        <string>sh</string>
        <string>bash</string>
        <string>zsh</string>
        <string>fish</string>
        <string>json</string>
        <string>jsonc</string>
        <string>yaml</string>
        <string>yml</string>
        <string>r</string>
        <string>xml</string>
        <string>toml</string>
      </array>
      <key>CFBundleTypeName</key>
      <string>Text and Source File Extensions</string>
      <key>CFBundleTypeOSTypes</key>
      <array>
        <string>TEXT</string>
        <string>utxt</string>
        <string>TUTX</string>
        <string>****</string>
      </array>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
    </dict>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' >"$APP_CONTENTS/PkgInfo"
echo "$APP_BUNDLE"
