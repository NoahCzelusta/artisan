# Native menus and shortcut routing

Status: ready-for-human

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

- 2026-06-16: Added `scripts/check-native-menus.sh` with a red/green benchmark mode for menu configuration and active-tab command routing.
- 2026-06-16: Added Edit menu items for undo, redo, cut, copy, paste, select all, find, find next, and find previous; added a minimal Window menu with Minimize and Zoom.
- 2026-06-16: Routed menu commands through the selected tab's `FastFileView` command methods and added practical menu validation for dirty save, undo/redo availability, selection-dependent cut/copy, and pasteboard-dependent paste.
- 2026-06-16: Focused gate passed with `benchmark.native_menus=PASS`.
- 2026-06-16: Full gates passed: native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `140 149 152 187 154` ms; immediate bottom render was `9.86` ms and scroll averaged `5.6869` ms.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for menu visibility, enabled/disabled states, and menu commands against the active tab.
