#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/ts-js-highlighting-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/ts-js-highlighting.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "typescript/javascript highlighting check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/sample.ts" <<'TXT'
const answer: number = 42;
// line comment
const message = "hello";
const block = /* inline */ answer;
TXT
cat >"$FIXTURE_DIR/component.tsx" <<'TXT'
export const View = ({name}: Props) => <Button disabled label="Save">{name}</Button>;
TXT
cat >"$FIXTURE_DIR/module.jsx" <<'TXT'
export function View() { return <section data-id="hero">Hello</section>; }
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-ts-js-highlighting "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark ts/js highlighting mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark ts/js highlighting mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.ts_js_highlighting=PASS$' "$RESULT_FILE" || fail "ts/js highlighting behavior did not pass"
echo "typescript/javascript highlighting check passed"
