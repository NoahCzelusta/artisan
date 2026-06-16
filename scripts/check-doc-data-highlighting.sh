#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/doc-data-highlighting-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/doc-data-highlighting.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "doc/data highlighting check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/README.md" <<'TXT'
# Heading
This has `inline code`, a [link](https://example.com), and **emphasis**.
```ts
const value = 1;
```
TXT
cat >"$FIXTURE_DIR/config.jsonc" <<'TXT'
{
  // comment
  "enabled": true,
  "count": 42,
  "name": null
}
TXT
cat >"$FIXTURE_DIR/config.yaml" <<'TXT'
# comment
name: "artisan"
enabled: true
count: 42
TXT
cat >"$FIXTURE_DIR/notes.txt" <<'TXT'
const should remain plain even with code-looking words.
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-doc-data-highlighting "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark doc/data highlighting mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark doc/data highlighting mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.doc_data_highlighting=PASS$' "$RESULT_FILE" || fail "doc/data highlighting behavior did not pass"
echo "doc/data highlighting check passed"
