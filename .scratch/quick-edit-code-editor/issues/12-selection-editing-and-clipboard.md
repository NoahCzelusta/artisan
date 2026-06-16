# Selection editing and clipboard

Status: ready-for-agent

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
