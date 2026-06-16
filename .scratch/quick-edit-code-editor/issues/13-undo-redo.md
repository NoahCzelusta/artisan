# Undo and redo

Status: ready-for-agent

## Summary

Implement undo and redo for text edits.

## Depends On

- 12-selection-editing-and-clipboard

## User Value

A user can recover from mistaken quick edits.

## Scope

- `Cmd-Z` undo.
- `Shift-Cmd-Z` redo.
- Coalesce typing bursts.
- Undo paste, cut, delete, newline, and selection replacement.
- Restore caret and selection reasonably.

## Acceptance Criteria

- Undo/redo works for all MVP edit commands.
- Typing burst is not one undo per low-level event unless that is intentionally chosen.
- Undo/redo near bottom of large file stays responsive.
- Benchmark gate passes.

## Verification

- Manual undo/redo pass across edit types.
- Run `scripts/run-benchmarks.sh`.

## Comments
