#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI="$ROOT_DIR/.github/workflows/ci.yml"
RELEASE="$ROOT_DIR/.github/workflows/release.yml"

fail() {
  echo "ci workflow check failed: $*" >&2
  exit 1
}

test -f "$CI" || fail "missing .github/workflows/ci.yml"
test -f "$RELEASE" || fail "missing .github/workflows/release.yml"

rg -q 'runs-on: macos-26' "$CI" || fail "CI must run on macos-26"
rg -q 'brew install ripgrep' "$CI" || fail "CI must install ripgrep for repo check scripts"
rg -q 'scripts/run-ci\.sh' "$CI" || fail "CI must call scripts/run-ci.sh"
rg -q 'actions/upload-artifact@v6' "$CI" || fail "CI must upload dry-run package artifacts"
rg -q 'scripts/check-release-package\.sh' "$CI" || fail "CI must produce a release package dry run"

rg -q 'tags:' "$RELEASE" || fail "release workflow must run from tags"
rg -q 'brew install ripgrep' "$RELEASE" || fail "release workflow must install ripgrep for repo check scripts"
rg -q 'scripts/package-release\.sh' "$RELEASE" || fail "release workflow must package release artifacts"
rg -q 'ARTISAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64' "$RELEASE" || fail "release workflow must require Developer ID certificate secret"
rg -q 'ARTISAN_NOTARY_API_KEY_BASE64' "$RELEASE" || fail "release workflow must require notary API key secret"
rg -q 'notarytool store-credentials artisan-ci' "$RELEASE" || fail "release workflow must store a CI notary profile"
rg -q 'ARTISAN_NOTARY_KEYCHAIN' "$RELEASE" || fail "release workflow must pass the temporary notary keychain"
rg -q 'spctl --assess' "$RELEASE" || fail "release workflow must validate Gatekeeper acceptance"
rg -q 'gh release create' "$RELEASE" || fail "release workflow must create GitHub Releases for tags"
rg -q 'pull-requests: write' "$RELEASE" || fail "release workflow must request pull request write permission"
rg -q 'Casks/artisan\.rb' "$RELEASE" || fail "release workflow must update the same-repo Homebrew cask"
rg -q 'gh pr create' "$RELEASE" || fail "release workflow must open a cask update PR"
rg -q 'git push --force-with-lease origin "\$branch"' "$RELEASE" || fail "release workflow must update a cask PR branch"
rg -q 'actions/upload-artifact@v6' "$RELEASE" || fail "release workflow must upload artifacts"

echo "ci workflow check passed"
