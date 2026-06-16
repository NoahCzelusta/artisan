#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
APP_NAME="Artisan"
EXECUTABLE_NAME="ArtisanApp"
BUNDLE_ID="com.noahczelusta.Artisan"
APP_BUNDLE="$ROOT_DIR/.build/release/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
SOCKET_PATH="/tmp/artisan-$(id -u).sock"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    shift || true
    ;;
  *)
    MODE="run"
    ;;
esac

APP_ARG_COUNT="$#"
APP_ARGS=()
for argument in "$@"; do
  if [[ "$argument" == --* || "$argument" == /* ]]; then
    APP_ARGS+=("$argument")
  else
    APP_ARGS+=("$(cd "$(dirname "$argument")" && pwd -P)/$(basename "$argument")")
  fi
done

kill_existing() {
  pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
  rm -f "$SOCKET_PATH"
}

build_bundle() {
  "$ROOT_DIR/scripts/build-artisan-app.sh" >/dev/null
}

open_app() {
  if [[ "$#" -gt 0 ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args "$@"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

open_app_with_args() {
  if [[ "$APP_ARG_COUNT" -gt 0 ]]; then
    open_app "${APP_ARGS[@]}"
  else
    open_app
  fi
}

kill_existing
build_bundle

case "$MODE" in
  run)
    open_app_with_args
    ;;
  --debug|debug)
    if [[ "$APP_ARG_COUNT" -gt 0 ]]; then
      lldb -- "$APP_BINARY" "${APP_ARGS[@]}"
    else
      lldb -- "$APP_BINARY"
    fi
    ;;
  --logs|logs)
    open_app_with_args
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app_with_args
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app_with_args
    sleep 1
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify] [file...]" >&2
    exit 2
    ;;
esac
