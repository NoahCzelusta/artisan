# Editor core tests

Status: ready-for-agent

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
