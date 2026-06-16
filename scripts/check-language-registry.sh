#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/language-registry-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/language-registry.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "language registry check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/app.ts" <<'TXT'
const value: string = "ok";
TXT
cat >"$FIXTURE_DIR/app.jsx" <<'TXT'
export const View = () => <div />;
TXT
cat >"$FIXTURE_DIR/README.md" <<'TXT'
# Artisan
TXT
cat >"$FIXTURE_DIR/config.yaml" <<'TXT'
name: artisan
TXT
cat >"$FIXTURE_DIR/config.xml" <<'TXT'
<config enabled="true" />
TXT
cat >"$FIXTURE_DIR/config.toml" <<'TXT'
enabled = true
TXT
cat >"$FIXTURE_DIR/Dockerfile" <<'TXT'
FROM scratch
TXT
cat >"$FIXTURE_DIR/Makefile" <<'TXT'
all:
	echo ok
TXT
cat >"$FIXTURE_DIR/script" <<'TXT'
#!/usr/bin/env python3
print("ok")
TXT
cat >"$FIXTURE_DIR/unknown.artisanfixture" <<'TXT'
plain fallback
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-language-registry "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark language registry mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark language registry mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.language_registry=PASS$' "$RESULT_FILE" || fail "language registry behavior did not pass"
echo "language registry check passed"
