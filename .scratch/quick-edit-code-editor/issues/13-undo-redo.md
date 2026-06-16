# Undo and redo

Status: ready-for-human

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

- 2026-06-16: Added `scripts/check-undo-redo.sh` with a red/green benchmark mode for typing coalescing, paste undo/redo, multi-line selection replacement undo/redo, cut undo/redo, newline undo/redo, and bottom-of-large-file undo/redo.
- 2026-06-16: Implemented compact line-range undo entries with caret/selection snapshots, `Cmd-Z`, `Shift-Cmd-Z`, redo clearing on new edits, and coalescing for consecutive single-character typing.
- 2026-06-16: Focused gate passed with `benchmark.undo_redo=PASS`; bottom-of-large-file undo/redo passed at `0.45` ms in the full regression run.
- 2026-06-16: Full gates passed: undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `138 147 148 151 151` ms; immediate bottom render was `16.05` ms and newline inserts averaged `5.6493` ms.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for `Cmd-Z`, `Shift-Cmd-Z`, typing coalescing, and undo/redo across paste, cut, delete, newline, and selection replacement.
