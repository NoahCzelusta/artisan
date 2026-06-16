#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRD="$ROOT_DIR/.scratch/quick-edit-code-editor/PRD.md"

fail() {
  echo "PRD check failed: $*" >&2
  exit 1
}

contains() {
  local pattern="$1"
  rg -q "$pattern" "$PRD" || fail "missing pattern: $pattern"
}

not_in_fast_follow() {
  local pattern="$1"
  awk '
    /^## Fast Follow$/ { in_fast_follow = 1; next }
    /^## / && in_fast_follow { in_fast_follow = 0 }
    in_fast_follow { print }
  ' "$PRD" | rg -q "$pattern" && fail "Fast Follow still contains: $pattern" || true
}

contains '^### Syntax Highlighting$'
contains '^### Keyboard Navigation and Selection$'
contains '^### Benchmarks$'
contains 'docs/benchmarks\.md'
contains 'docs/syntax-highlighting\.md'
contains 'No language servers'
contains 'No project indexing'
contains 'No extensions'
contains 'No integrated terminal'
contains 'No creating new files'

not_in_fast_follow 'Syntax highlighting'

echo "PRD check passed"
