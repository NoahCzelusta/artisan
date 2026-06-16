# Save, dirty state, and close prompts

Status: ready-for-human

## Summary

Implement safe saving and dirty-tab behavior.

## Depends On

- 07-edit-visible-text
- 05-implement-session-tabs

## User Value

A user can safely save quick edits and avoid losing unsaved changes.

## Scope

- `Cmd-S` save.
- Dirty tab indicator.
- Close dirty tab prompt.
- Close window/app dirty prompt.
- Atomic save.
- Preserve line endings and final newline presence.

## Acceptance Criteria

- `Cmd-S` writes changes to disk.
- Dirty tabs are visually marked.
- Closing dirty tab prompts save/discard/cancel.
- Quitting with dirty tabs prompts safely.
- Saves are atomic.
- LF vs CRLF and final newline presence are preserved.
- Benchmark gate passes.

## Verification

- Edit/save a small fixture and inspect file contents.
- Edit a CRLF fixture and confirm CRLF preservation.
- Close dirty tab and verify all prompt branches.
- Run `scripts/run-benchmarks.sh`.

## Comments

- Implemented core save support:
  - `Cmd-S` saves the selected document.
  - Tabs are marked dirty with `*` after edits and reset after save.
  - Saves use `Data.write(..., options: .atomic)`.
  - Existing LF vs CRLF line endings are preserved.
  - Existing final-newline presence is preserved for normal edits.
  - Dirty tab/window/app close paths show Save / Discard / Cancel prompts.
- Added `scripts/check-save-operations.sh` for deterministic save behavior.
- Verification completed:
  - Red: `scripts/check-save-operations.sh` initially timed out because save benchmark mode did not exist.
  - Green: `scripts/check-save-operations.sh` passed with `benchmark.save_operations=PASS`.
  - `scripts/check-edit-operations.sh` passed.
  - `scripts/check-cli-wait.sh` passed.
  - `scripts/check-cli-open-existing-files.sh` passed.
  - `scripts/check-plain-text-rendering.sh` passed.
  - `scripts/check-production-targets.sh` passed.
  - `scripts/check-mvp-prd.sh` passed.
  - `scripts/run-benchmarks.sh` passed with cold CLI runs `222 217 232 223 235` ms.
- Remaining human verification:
  - Confirm dirty tab label visually after a manual edit.
  - Confirm `Cmd-S` writes the visible manual edit to disk.
  - Confirm dirty close prompt branches: Save, Discard, and Cancel.
  - Confirm quitting with a dirty tab prompts and respects Cancel.
- Blocker for agent-side UI verification:
  - Computer Use could inspect the app but refused click/key actions in this app session after fresh `get_app_state` calls.
  - System Events keystrokes were blocked by macOS accessibility permissions.
  - CoreGraphics synthetic key events posted without error but did not affect the app.
