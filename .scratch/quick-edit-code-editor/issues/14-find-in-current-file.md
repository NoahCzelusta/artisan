# Find in current file

Status: ready-for-agent

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
