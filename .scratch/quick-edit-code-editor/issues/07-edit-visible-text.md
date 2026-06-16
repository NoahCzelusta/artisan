# Edit visible text

Status: done

## Summary

Implement basic visible text editing: character insertion, backspace/delete, newline, and paste replacement at the caret.

## Depends On

- 03-open-and-render-existing-file

## User Value

A user can make quick edits in an opened file.

## Scope

- Mutable text buffer.
- Character insertion.
- Backspace/delete adjacent character.
- Newline insertion.
- Paste plain text at caret.
- Caret stays visible after edits.
- No selection required yet.

## Acceptance Criteria

- Typing inserts text at caret.
- Backspace/delete remove adjacent text.
- Return inserts newline.
- Pasting text inserts at caret.
- Edits near top, middle, and bottom of a 10 MiB file remain responsive.
- Benchmark gate passes.

## Verification

- Manually edit a small file.
- Manually edit near bottom of a large file.
- Run `scripts/run-benchmarks.sh`.

## Comments

- Added `scripts/check-edit-operations.sh` for insertion, backspace, forward delete, newline, and multi-line paste behavior.
- Added `TextBuffer.insertText` for multi-line plain-text paste.
- Added `TextBuffer.deleteForward` for forward delete.
- Wired `Cmd-V` to paste plain text from `NSPasteboard`.
- Added `benchmark.bottom_insert_delete_ms` so edits near the bottom of a 10 MiB file are covered by the reproducible benchmark gate.
- Verification:
  - Red: `scripts/check-edit-operations.sh` initially timed out because edit benchmark mode did not exist.
  - Green: `scripts/check-edit-operations.sh` passed with `benchmark.edit_operations=PASS`.
  - Computer Use verified visible typing, backspace, Return/newline, and Cmd-V multi-line paste in a small file.
  - `scripts/check-cli-wait.sh` passed.
  - `scripts/check-cli-open-existing-files.sh` passed.
  - `scripts/check-plain-text-rendering.sh` passed.
  - `scripts/check-production-targets.sh` passed.
  - `scripts/check-mvp-prd.sh` passed.
  - `scripts/run-benchmarks.sh` passed with `benchmark.bottom_insert_delete_ms=2.61` and cold CLI runs `217 209 234 206 232` ms.
