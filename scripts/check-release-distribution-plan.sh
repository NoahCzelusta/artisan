#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT_DIR/docs/distribution.md"

fail() {
  echo "release distribution plan check failed: $*" >&2
  exit 1
}

test -f "$DOC" || fail "missing docs/distribution.md"

required_patterns=(
  "# Release Distribution"
  "Apple Developer Program"
  "Developer ID Application"
  "hardened runtime"
  "notarytool"
  "stapler"
  "GitHub Releases"
  "Homebrew Cask"
  "same-repo"
  "Casks/artisan.rb"
  "homebrew-cask"
  "sha256"
  "scripts/package-release.sh"
  ".github/workflows/ci.yml"
  ".github/workflows/release.yml"
  "ARTISAN_CODESIGN_IDENTITY"
  "ARTISAN_NOTARY_KEYCHAIN_PROFILE"
  "ARTISAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64"
  "ARTISAN_NOTARY_API_KEY_BASE64"
  "dist/artisan.rb"
  "CI is configured"
  "License decision: deferred"
  "GitHub signing secret provisioning"
)

for pattern in "${required_patterns[@]}"; do
  rg --fixed-strings --quiet "$pattern" "$DOC" || fail "missing required text: $pattern"
done

echo "release distribution plan check passed"
