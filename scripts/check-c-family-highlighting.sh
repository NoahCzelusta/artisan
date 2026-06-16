#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/c-family-highlighting-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/c-family-highlighting.txt"
APP="$ROOT_DIR/.build/release/ArtisanApp"

fail() {
  echo "c-family highlighting check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/main.c" <<'TXT'
int main() { return 42; } // c comment
const char *name = "artisan";
TXT
cat >"$FIXTURE_DIR/main.cpp" <<'TXT'
template <typename T> auto value = 42; // cpp comment
std::string name = "artisan";
TXT
cat >"$FIXTURE_DIR/Main.cs" <<'TXT'
public class Program { static int Value = 42; } // cs comment
var name = "artisan";
TXT
cat >"$FIXTURE_DIR/Main.java" <<'TXT'
public class Main { private int value = 42; } // java comment
String name = "artisan";
TXT
cat >"$FIXTURE_DIR/main.go" <<'TXT'
func main() { var value int = 42 } // go comment
name := "artisan"
TXT
cat >"$FIXTURE_DIR/main.rs" <<'TXT'
fn main() { let value: i32 = 42; } // rust comment
let name = "artisan";
TXT
cat >"$FIXTURE_DIR/main.swift" <<'TXT'
func main() { let value: Int = 42 } // swift comment
let name = "artisan"
TXT
cat >"$FIXTURE_DIR/Main.kt" <<'TXT'
fun main() { val value: Int = 42 } // kotlin comment
val name = "artisan"
TXT

cd "$ROOT_DIR"
swift build -c release >/dev/null

"$APP" --benchmark-c-family-highlighting "$FIXTURE_DIR" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark c-family highlighting mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark c-family highlighting mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.c_family_highlighting=PASS$' "$RESULT_FILE" || fail "c-family highlighting behavior did not pass"
echo "c-family highlighting check passed"
