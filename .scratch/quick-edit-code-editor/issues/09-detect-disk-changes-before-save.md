# Detect disk changes before save

Status: ready-for-agent

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
