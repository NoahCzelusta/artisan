# Selection model and rendering

Status: ready-for-human

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

- 2026-06-16: Added the red/green selection gate in `scripts/check-selection-model.sh`; the initial red state was a benchmark-mode timeout, and the current green state prints `benchmark.selection_model=PASS`.
- 2026-06-16: Implemented anchor/active selection state, shift-extended character/word/line/file navigation, mouse drag selection, double-click word selection, triple-click line selection, and multi-line selection background rendering.
- 2026-06-16: Automated gates passed: selection model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `139 147 155 157 155` ms; immediate bottom render was `14.83` ms and scroll average was `5.7245` ms per step.
- 2026-06-16: Computer Use could enumerate Artisan as running, but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for keyboard selection, mouse drag/double/triple click selection, and selection near the bottom of a large file.
