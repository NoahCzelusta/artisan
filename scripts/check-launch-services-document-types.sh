#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/.scratch/launch-services-fixtures"
RESULT_FILE="$ROOT_DIR/.scratch/benchmark-results/launch-services.txt"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

fail() {
  echo "launch services document type check failed: $*" >&2
  exit 1
}

mkdir -p "$FIXTURE_DIR" "$(dirname "$RESULT_FILE")"
cat >"$FIXTURE_DIR/sample.txt" <<'TXT'
plain text
TXT
cat >"$FIXTURE_DIR/README.md" <<'MD'
# Markdown
MD
cat >"$FIXTURE_DIR/sample.ts" <<'TS'
const value: number = 1;
TS

cd "$ROOT_DIR"
APP_BUNDLE="$("$ROOT_DIR/scripts/build-artisan-app.sh" | tail -n 1)"
APP="$ROOT_DIR/.build/release/ArtisanApp"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

test -d "$APP_BUNDLE" || fail "missing app bundle"
test -x "$APP" || fail "missing ArtisanApp executable"
plutil -lint "$INFO_PLIST" >/dev/null || fail "generated Info.plist is invalid"
plutil -p "$INFO_PLIST" | rg -q 'CFBundleDocumentTypes' || fail "Info.plist missing document types"
plutil -p "$INFO_PLIST" | rg -q 'public\.text' || fail "Info.plist missing public.text support"
plutil -p "$INFO_PLIST" | rg -q 'public\.source-code' || fail "Info.plist missing source-code support"
plutil -p "$INFO_PLIST" | rg -q 'LSHandlerRank.*Alternate' || fail "document type rank should be Alternate"

"$APP" --benchmark-launch-services-open "$FIXTURE_DIR/sample.txt" >"$RESULT_FILE" &
pid="$!"

for _ in $(seq 1 50); do
  if ! kill -0 "$pid" >/dev/null 2>&1; then
    wait "$pid" || fail "benchmark launch-services open mode exited non-zero"
    break
  fi
  sleep 0.1
done

if kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" >/dev/null 2>&1 || true
  fail "benchmark launch-services open mode timed out"
fi

cat "$RESULT_FILE"
rg -q '^benchmark.launch_services_open=PASS$' "$RESULT_FILE" || fail "app delegate open-file behavior did not pass"

"$LSREGISTER" -f "$APP_BUNDLE"

for fixture in "$FIXTURE_DIR/sample.txt" "$FIXTURE_DIR/README.md" "$FIXTURE_DIR/sample.ts"; do
  swift - "$APP_BUNDLE" "$fixture" <<'SWIFT'
import AppKit
import Foundation

let expectedApp = URL(fileURLWithPath: CommandLine.arguments[1])
    .standardizedFileURL
    .resolvingSymlinksInPath()
let file = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
let applications = NSWorkspace.shared.urlsForApplications(toOpen: file)
let matches = applications.contains { candidate in
    candidate.standardizedFileURL.resolvingSymlinksInPath().path == expectedApp.path
}

if !matches {
    let appList = applications
        .map { $0.lastPathComponent }
        .sorted()
        .joined(separator: ", ")
    fputs("Artisan.app was not listed for \(file.path). Apps: \(appList)\n", stderr)
    exit(1)
}
SWIFT
done

echo "launch services document type check passed"
