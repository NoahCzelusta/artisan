# Refresh MVP PRD

Status: done

## Summary

Update the PRD so the MVP scope matches the current product direction before implementation continues.

## Depends On

None.

## User Value

The team has one source of truth for what counts as MVP.

## Scope

- Move viewport-bounded syntax highlighting into MVP.
- Add keyboard navigation, selection, clipboard, undo/redo, and find as MVP editor basics.
- Add benchmark gates as MVP requirements.
- Keep non-goals explicit: no language servers, no project indexing, no extensions, no integrated terminal, no new-file creation.

## Acceptance Criteria

- `.scratch/quick-edit-code-editor/PRD.md` reflects current MVP scope.
- Fast-follow section no longer conflicts with MVP issues.
- Performance requirements point to `docs/benchmarks.md`.
- Syntax highlighting scope points to `docs/syntax-highlighting.md`.

## Verification

- Read the PRD and confirm each MVP issue maps to an MVP requirement.

## Comments

Completed on 2026-06-16.

Verification:

- `scripts/check-mvp-prd.sh` passed.
- `scripts/run-benchmarks.sh` passed.
- Computer Use verification not applicable: this issue only updates PRD documentation and has no app UI behavior.
