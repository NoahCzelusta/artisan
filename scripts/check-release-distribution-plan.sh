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
  "private tap"
  "homebrew-cask"
  "sha256"
  "License decision: deferred"
  "CI decision: deferred"
)

for pattern in "${required_patterns[@]}"; do
  rg --fixed-strings --quiet "$pattern" "$DOC" || fail "missing required text: $pattern"
done

echo "release distribution plan check passed"
