# Find in current file

Status: ready-for-human

## Summary

Implement basic find within the active file.

## Depends On

- 11-selection-model-and-rendering

## User Value

A user can locate text in a file without opening an IDE.

## Scope

- `Cmd-F` find UI.
- Search active file only.
- Next/previous result.
- Highlight visible matches.
- No project-wide search.

## Acceptance Criteria

- Find works in small and large files.
- Next/previous scrolls result into view.
- Match highlight coexists with selection/caret.
- Large-file search remains responsive.
- Benchmark gate passes.

## Verification

- Find common string in generated large fixture.
- Navigate next/previous across far-apart matches.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-find.sh` with a red/green benchmark mode for literal find, next/previous wrapping, visible match columns, and large-file search across far-apart matches.
- 2026-06-16: Implemented active-file find state in `FastFileView`, visible match highlighting, active match selection, next/previous wrap navigation, and scroll-to-result.
- 2026-06-16: Added native menu actions for `Cmd-F` Find, `Cmd-G` Find Next, and `Shift-Cmd-G` Find Previous using a small sheet-based find UI.
- 2026-06-16: Focused gate passed with `benchmark.find=PASS`; large-file find passed at `30.53` ms in the full regression run.
- 2026-06-16: Full gates passed: find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `142 147 150 146 146` ms; immediate bottom render was `18.14` ms and scroll averaged `5.6355` ms.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for `Cmd-F`, `Cmd-G`, `Shift-Cmd-G`, visible highlight appearance, and navigating matches in a large file.
