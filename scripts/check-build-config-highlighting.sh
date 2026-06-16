#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/build-config-highlighting-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/build-config-highlighting.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "build/config highlighting check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/Makefile" <<'TXT'
all: build
VALUE = "artisan" # make comment
	echo "build"
TXT
cat >"$FIXTURE_DIR/Dockerfile" <<'TXT'
FROM scratch
RUN echo "artisan" # docker comment
ENV ANSWER=42
TXT
cat >"$FIXTURE_DIR/config.xml" <<'TXT'
<!-- xml comment -->
<config enabled="true">artisan</config>
TXT
cat >"$FIXTURE_DIR/config.toml" <<'TXT'
[server.main]
enabled = true
count = 42
name = "artisan" # toml comment
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-build-config-highlighting "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark build/config highlighting mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark build/config highlighting mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.build_config_highlighting=PASS$' "$RESULT_FILE" || fail "build/config highlighting behavior did not pass"
echo "build/config highlighting check passed"
