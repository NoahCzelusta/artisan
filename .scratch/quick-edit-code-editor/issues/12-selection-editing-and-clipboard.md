# Selection editing and clipboard

Status: ready-for-human

## Summary

Implement selection replacement plus standard clipboard commands.

## Depends On

- 11-selection-model-and-rendering

## User Value

A user can copy, cut, paste, replace, and delete selected text.

## Scope

- `Cmd-A` select all.
- `Cmd-C` copy.
- `Cmd-X` cut.
- `Cmd-V` paste.
- Typing replaces selected text.
- Backspace/delete remove selected text.

## Acceptance Criteria

- Clipboard operations work with single-line and multi-line selections.
- Selection replacement works for typing and paste.
- `Cmd-A` works on small and large files.
- Cut/delete dirty the document.
- Benchmark gate passes.

## Verification

- Manual copy/cut/paste pass.
- Replace multi-line selection.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-selection-editing.sh` with a red/green benchmark mode for select-all, copy, cut, paste replacement, typing replacement, selection delete, and large-file select-all.
- 2026-06-16: Implemented selection text extraction/deletion in `TextBuffer`, selection-aware typing/paste/delete in the editor, and `Cmd-A`/`Cmd-C`/`Cmd-X`/`Cmd-V` routing.
- 2026-06-16: Focused gate passed with `benchmark.selection_editing=PASS`; large-file select-all passed at `0.57` ms in the full regression run.
- 2026-06-16: Full gates passed: selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `143 154 146 149 146` ms; immediate bottom render was `9.37` ms and newline inserts recovered to `5.0654` ms average after tightening cache invalidation.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for copy/cut/paste, replacing selected text, deleting a multi-line selection, and select-all in a large file.
