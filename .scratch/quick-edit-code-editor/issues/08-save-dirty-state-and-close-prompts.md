# Save, dirty state, and close prompts

Status: ready-for-agent

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
