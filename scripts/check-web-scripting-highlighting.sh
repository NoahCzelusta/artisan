#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/web-scripting-highlighting-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/web-scripting-highlighting.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "web/scripting highlighting check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/app.py" <<'TXT'
def main():
    value = 42  # python comment
    name = "artisan"
TXT
cat >"$FIXTURE_DIR/app.rb" <<'TXT'
def main
  value = 42 # ruby comment
  name = "artisan"
end
TXT
cat >"$FIXTURE_DIR/app.php" <<'TXT'
<?php function main() { $value = 42; } // php comment
$name = "artisan";
TXT
cat >"$FIXTURE_DIR/run-script" <<'TXT'
#!/usr/bin/env bash
value=42 # shell comment
echo "artisan"
TXT
cat >"$FIXTURE_DIR/query.sql" <<'TXT'
SELECT count(*) FROM users WHERE active = 1; -- sql comment
SELECT 'artisan';
TXT
cat >"$FIXTURE_DIR/index.html" <<'TXT'
<!-- html comment -->
<section data-id="hero">Hello</section>
TXT
cat >"$FIXTURE_DIR/styles.css" <<'TXT'
/* css comment */
.hero { color: "red"; margin: 42px; }
TXT
cat >"$FIXTURE_DIR/analysis.r" <<'TXT'
value <- 42 # r comment
name <- "artisan"
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-web-scripting-highlighting "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark web/scripting highlighting mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark web/scripting highlighting mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.web_scripting_highlighting=PASS$' "$RESULT_FILE" || fail "web/scripting highlighting behavior did not pass"
echo "web/scripting highlighting check passed"
