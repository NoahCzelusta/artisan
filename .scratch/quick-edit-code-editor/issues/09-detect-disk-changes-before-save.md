# Detect disk changes before save

Status: ready-for-human

## Summary

Warn when a file changed on disk after Artisan opened it.

## Depends On

- 08-save-dirty-state-and-close-prompts

## User Value

A user does not accidentally overwrite agent or external edits.

## Scope

- Record file state at open/save.
- Detect external changes before save.
- Warn with reload, save anyway, or cancel.
- Avoid noisy polling.

## Acceptance Criteria

- If another process changes the file, save warns before overwrite.
- Reload updates the buffer from disk.
- Save anyway overwrites intentionally.
- Cancel keeps current buffer unchanged.
- Benchmark gate passes.

## Verification

- Open a file, modify it externally, edit in Artisan, hit `Cmd-S`.
- Verify each prompt branch.
- Run `scripts/run-benchmarks.sh`.

## Comments

- Added disk-change detection before save using file metadata snapshots captured at open/save/reload.
- Added reload support that discards local edits and refreshes the buffer from disk.
- Added save-time external-change prompt with Reload / Save Anyway / Cancel branches.
- Fixed line decoding for one-line files with a final newline; `lineText(at:)` no longer includes a trailing LF.
- Added `scripts/check-disk-change-save.sh` for deterministic cancel/reload/save-anyway behavior.
- Verification completed:
  - Red: `scripts/check-disk-change-save.sh` initially timed out because disk-change benchmark mode did not exist.
  - Green: `scripts/check-disk-change-save.sh` passed with `benchmark.disk_change_save=PASS`.
  - Full sequential gate sweep passed: `scripts/check-disk-change-save.sh`, `scripts/check-save-operations.sh`, `scripts/check-edit-operations.sh`, `scripts/check-cli-wait.sh`, `scripts/check-cli-open-existing-files.sh`, `scripts/check-plain-text-rendering.sh`, `scripts/check-production-targets.sh`, `scripts/check-mvp-prd.sh`, and `scripts/run-benchmarks.sh`.
  - Latest benchmark cold CLI runs: `135 144 146 148 150` ms.
- Performance note:
  - An initial content-hash snapshot regressed 10 MiB open time to `41.45 ms`, so snapshots now use filesystem metadata only; the benchmark gate returned to `benchmark.open_ms=3.19`.
- Remaining human verification:
  - Open a file, modify it externally, edit in Artisan, hit `Cmd-S`.
  - Verify Reload updates the editor from disk.
  - Verify Save Anyway overwrites intentionally.
  - Verify Cancel keeps the current buffer unchanged.
- Blocker for agent-side UI verification:
  - Computer Use currently reports `cgWindowNotFound` for Artisan after both CLI and LaunchServices launches.
  - Shell screenshot and assistive-access probes are blocked by macOS permissions.
