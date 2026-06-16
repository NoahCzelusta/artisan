# Selection model and rendering

Status: ready-for-agent

## Summary

Implement selection state and rendering for keyboard and mouse selection.

## Depends On

- 10-keyboard-navigation

## User Value

A user can select text before copy/cut/delete/replacement.

## Scope

- Selection anchor and active end.
- Shift navigation extends selection.
- Mouse drag selection.
- Double-click word selection.
- Triple-click line selection if feasible.
- Multi-line selection rendering.
- Click clears selection and places caret.

## Acceptance Criteria

- `Shift-Arrow` extends selection.
- `Shift-Option-Arrow` extends by word.
- `Shift-Command-Arrow` extends to line/file boundaries.
- Mouse drag selects text.
- Selected text renders across visible lines.
- Selection works after scrolling in large files.
- Benchmark gate passes.

## Verification

- Manual keyboard selection pass.
- Manual mouse selection pass.
- Select text near bottom of large file.
- Run `scripts/run-benchmarks.sh`.

## Comments
