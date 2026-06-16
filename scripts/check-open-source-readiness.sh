#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "open source readiness check failed: $*" >&2
  exit 1
}

required_files=(
  LICENSE
  README.md
  CONTRIBUTING.md
  SECURITY.md
  CODE_OF_CONDUCT.md
  .github/pull_request_template.md
  .github/ISSUE_TEMPLATE/bug_report.yml
  .github/ISSUE_TEMPLATE/feature_request.yml
  .github/ISSUE_TEMPLATE/config.yml
  skills/cut-artisan-release/SKILL.md
)

for file in "${required_files[@]}"; do
  test -f "$ROOT_DIR/$file" || fail "missing $file"
done

rg --fixed-strings --quiet "MIT License" "$ROOT_DIR/LICENSE" || fail "LICENSE must be MIT"
rg --fixed-strings --quiet "Copyright (c) 2026 Noah Czelusta" "$ROOT_DIR/LICENSE" || fail "LICENSE copyright is missing"
rg --fixed-strings --quiet "## License" "$ROOT_DIR/README.md" || fail "README must mention license"
rg --fixed-strings --quiet "MIT License" "$ROOT_DIR/README.md" || fail "README must link MIT license"
rg --fixed-strings --quiet "scripts/run-ci.sh" "$ROOT_DIR/CONTRIBUTING.md" || fail "CONTRIBUTING must document local CI"
rg --fixed-strings --quiet "private vulnerability" "$ROOT_DIR/SECURITY.md" || fail "SECURITY must document private reporting"
rg --fixed-strings --quiet "labels: [\"needs-triage\"]" "$ROOT_DIR/.github/ISSUE_TEMPLATE/bug_report.yml" || fail "bug template must use triage label"
rg --fixed-strings --quiet "labels: [\"needs-triage\"]" "$ROOT_DIR/.github/ISSUE_TEMPLATE/feature_request.yml" || fail "feature template must use triage label"
rg --fixed-strings --quiet "pull-requests: write" "$ROOT_DIR/.github/workflows/release.yml" || fail "release workflow must be able to open cask PRs"
rg --fixed-strings --quiet "gh pr create" "$ROOT_DIR/.github/workflows/release.yml" || fail "release workflow must create cask PRs"
rg --fixed-strings --quiet 'protected \`main\`' "$ROOT_DIR/.github/workflows/release.yml" || fail "release workflow must explain protected main cask PR flow"

echo "open source readiness check passed"
