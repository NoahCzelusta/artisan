# Editor core tests

Status: ready-for-human

## Summary

Add focused correctness tests for editor core behavior.

## Depends On

- 13-undo-redo
- 16-language-detection-and-highlighter-registry

## User Value

Core editing behavior stays correct as the implementation evolves.

## Scope

- Text buffer edits.
- Selection replacement.
- Undo/redo.
- Save semantics.
- Language detection.
- Unsupported file rejection.

## Acceptance Criteria

- Tests cover top, middle, and bottom edits in large files.
- Tests cover selection replacement.
- Tests cover line ending and final newline preservation.
- Tests cover documented language detection cases.
- Tests run locally with one command.

## Verification

- Run the test command.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-editor-core.sh` as the one-command local editor-core correctness check.
- 2026-06-16: Added `--benchmark-editor-core` to cover top, middle, and bottom text-buffer edits in a 30k-line fixture.
- 2026-06-16: The editor-core script also runs the focused selection editing, undo/redo, save semantics, language registry, and CLI open/rejection gates.
- 2026-06-16: Focused gate passed with `benchmark.editor_core=PASS`.
- 2026-06-16: Full gates passed: editor core, preferences, web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `138 147 142 149 155` ms; immediate bottom render was `9.03` ms and scroll averaged `4.7180` ms.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed only for UI-visible behavior; the editor-core command itself is automated.
