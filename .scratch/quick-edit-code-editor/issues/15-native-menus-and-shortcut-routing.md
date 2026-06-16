# Native menus and shortcut routing

Status: ready-for-agent

## Summary

Implement native macOS menus and command routing for the completed editor basics.

## Depends On

- 08-save-dirty-state-and-close-prompts
- 12-selection-editing-and-clipboard
- 13-undo-redo
- 14-find-in-current-file

## User Value

Artisan behaves like a normal macOS editor, not a custom canvas with hidden commands.

## Scope

- File menu.
- Edit menu.
- Window menu where applicable.
- Active-tab command routing.
- Enabled/disabled menu states where practical.

## Acceptance Criteria

- Menus expose open, save, close, quit, undo, redo, cut, copy, paste, select all, and find.
- Shortcuts route to active tab.
- Menu commands match keyboard behavior.
- Benchmark gate passes.

## Verification

- Manual menu command pass.
- Run `scripts/run-benchmarks.sh`.

## Comments
