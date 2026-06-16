# Minimal preferences

Status: ready-for-human

## Summary

Implement low-risk display preferences without introducing workspace state.

## Depends On

- 03-open-and-render-existing-file

## User Value

Users can make the editor comfortable without turning Artisan into an IDE.

## Scope

- Font size preference.
- Theme preference if themes exist.
- Window size preference.
- No tab restore.
- No project/workspace restore.

## Acceptance Criteria

- Preferences persist across app launches.
- Previous tabs do not restore.
- Preferences do not materially affect launch performance.
- Benchmark gate passes.

## Verification

- Change preference, quit, reopen, confirm retained.
- Open files, quit, reopen app without args, confirm tabs are not restored.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-minimal-preferences.sh` with a red/green benchmark mode for persisted font size and window frame preferences.
- 2026-06-16: Added `EditorPreferences` backed by `UserDefaults` for clamped editor font size and saved window frame.
- 2026-06-16: Added a Preferences menu item (`Cmd-,`) with a small font-size sheet and live application to open tabs.
- 2026-06-16: Window frame now persists on move/resize; tabs/session state remain intentionally unpersisted.
- 2026-06-16: Focused gate passed with `benchmark.preferences=PASS`.
- 2026-06-16: Full gates passed: preferences, web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `142 152 151 154 154` ms; immediate bottom render was `13.86` ms and scroll averaged `4.7213` ms.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for the Preferences sheet, persisted font size, persisted window size, and no tab restore after relaunch without args.
