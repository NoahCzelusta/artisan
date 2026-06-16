# Implement session tabs

Status: done

## Summary

Implement one primary window with session tabs that are not restored across launches.

## Depends On

- 04-cli-open-existing-files

## User Value

A user can work across several opened files without Artisan becoming a project/workspace editor.

## Scope

- One primary window.
- One tab per opened file.
- Close tab behavior.
- Focus tab when opened again.
- No previous-tab restore.
- Optional window-size preference only.

## Acceptance Criteria

- Multiple CLI paths appear as tabs in one window.
- `Cmd-O` adds tabs.
- Closing a tab removes it from the session.
- Quitting and reopening does not restore previous tabs.
- Benchmark gate passes.

## Verification

- Open three files from CLI and with `Cmd-O`.
- Close and reopen app; confirm old tabs are gone.
- Run `scripts/run-benchmarks.sh`.

## Comments

- The production app already had one-window session tabs, focus-existing-tab behavior, and close-tab handling from the prototype.
- Added `window.isRestorable = false` to make the no-restore session contract explicit.
- Fixed `script/build_and_run.sh --verify` with zero file arguments after the no-restore check exposed an empty-array `set -u` failure.
- Verification:
  - Computer Use confirmed `artisan README.md CONTEXT.md Package.swift` opened three tabs in one window.
  - Computer Use confirmed `Cmd-W` closed the selected tab and left the remaining two session tabs.
  - Computer Use confirmed quitting and reopening with no file arguments produced a blank window with no restored tabs.
  - Computer Use confirmed `Cmd-O` opened the native panel and added `CONTEXT.md` as a tab.
  - Sequential gate sweep passed: `scripts/check-cli-open-existing-files.sh`, `scripts/check-plain-text-rendering.sh`, `scripts/check-production-targets.sh`, `scripts/check-mvp-prd.sh`, and `scripts/run-benchmarks.sh`.
  - Latest benchmark cold CLI runs: `228 223 226 228 229` ms.
