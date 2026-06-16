#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$ROOT_DIR/Package.swift"
BENCH="$ROOT_DIR/scripts/run-benchmarks.sh"
README="$ROOT_DIR/README.md"
BUNDLE_SCRIPT="$ROOT_DIR/scripts/build-artisan-app.sh"

fail() {
  echo "production target check failed: $*" >&2
  exit 1
}

rg -q 'executable\(name: "ArtisanApp"' "$PACKAGE" || fail "Package.swift must define ArtisanApp executable product"
rg -q 'executable\(name: "artisan"' "$PACKAGE" || fail "Package.swift must define artisan executable product"
rg -q 'executableTarget\(name: "ArtisanApp"' "$PACKAGE" || fail "Package.swift must define ArtisanApp executable target"
rg -q 'executableTarget\(name: "artisan"' "$PACKAGE" || fail "Package.swift must define artisan executable target"

rg -q 'APP="\$ROOT_DIR/\.build/release/ArtisanApp"' "$BENCH" || fail "benchmark runner must use production ArtisanApp"
rg -q 'CLI="\$ROOT_DIR/\.build/release/artisan"' "$BENCH" || fail "benchmark runner must use production artisan CLI"

test -x "$BUNDLE_SCRIPT" || fail "scripts/build-artisan-app.sh must exist and be executable"
rg -q 'swift build -c release' "$README" || fail "README must document release build"
rg -q '\.build/release/artisan' "$README" || fail "README must document production artisan CLI path"
rg -q '\.build/release/Artisan\.app' "$README" || fail "README must document local app bundle path"

echo "production target check passed"
