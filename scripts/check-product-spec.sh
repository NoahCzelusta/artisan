#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT_DIR/SPEC.md"

fail() {
  echo "product spec check failed: $*" >&2
  exit 1
}

contains() {
  local pattern="$1"
  rg -q "$pattern" "$SPEC" || fail "missing pattern: $pattern"
}

not_in_fast_follow() {
  local pattern="$1"
  awk '
    /^## Fast Follow$/ { in_fast_follow = 1; next }
    /^## / && in_fast_follow { in_fast_follow = 0 }
    in_fast_follow { print }
  ' "$SPEC" | rg -q "$pattern" && fail "Fast Follow still contains: $pattern" || true
}

contains '^## Syntax Highlighting$'
contains '^## Keyboard Navigation And Selection$'
contains '^## Performance Requirements$'
contains '^## Packaging And Distribution$'
contains 'Language servers'
contains 'Project indexing'
contains 'Extension or plugin system'
contains 'Integrated terminal'
contains 'Never create an unsaved buffer'

not_in_fast_follow 'Syntax highlighting'

echo "product spec check passed"
