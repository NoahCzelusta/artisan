# Keyboard navigation

Status: ready-for-human

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

- Implemented standard navigation without selection:
  - Left / Right move by character and cross line boundaries.
  - Up / Down move by line.
  - Option-Left / Option-Right move by word using whitespace and punctuation as separators.
  - Command-Left / Command-Right move to current-line boundaries.
  - Command-Up / Command-Down move to file boundaries.
  - Page Up / Page Down move by viewport and clamp to file bounds.
  - Home / End move to current-line boundaries.
- Added `docs/keyboard-navigation.md` documenting the shortcut contract, including Home / End behavior.
- Added `scripts/check-keyboard-navigation.sh` with an in-app benchmark mode for exact caret-position checks.
- Verification completed:
  - Red: `scripts/check-keyboard-navigation.sh` initially timed out because keyboard-navigation benchmark mode did not exist.
  - Red: the same check then failed until `docs/keyboard-navigation.md` documented Home / End.
  - Green: `scripts/check-keyboard-navigation.sh` passed with `benchmark.keyboard_navigation=PASS`.
  - `scripts/run-benchmarks.sh` passed with cold CLI runs `137 153 155 149 144` ms.
- Remaining human verification:
  - Manual shortcut pass in a small file.
  - Manual shortcut pass near the top, middle, and bottom of a large file.
- Blocker for agent-side UI verification:
  - Computer Use still reports `cgWindowNotFound` for Artisan after a normal `.app` launch, so keyboard shortcuts could not be verified through live UI automation in this turn.
