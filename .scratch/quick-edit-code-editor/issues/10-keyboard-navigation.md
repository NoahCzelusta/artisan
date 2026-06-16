# Keyboard navigation

Status: ready-for-agent

## Summary

Implement standard macOS keyboard navigation without selection.

## Depends On

- 07-edit-visible-text

## User Value

A non-Vim user can move around text naturally with familiar macOS shortcuts.

## Scope

- Arrow keys by character/line.
- `Option-Left` / `Option-Right` by word.
- `Command-Left` / `Command-Right` to line boundaries.
- `Command-Up` / `Command-Down` to file boundaries.
- Page Up / Page Down by viewport.
- Home / End behavior documented and implemented.
- Keep caret visible.

## Acceptance Criteria

- Each shortcut moves caret as documented.
- Word movement handles punctuation and whitespace reasonably.
- Movement works near top, middle, and bottom of large files.
- Benchmark gate passes.

## Verification

- Manual shortcut pass in small and large files.
- Run `scripts/run-benchmarks.sh`.

## Comments
