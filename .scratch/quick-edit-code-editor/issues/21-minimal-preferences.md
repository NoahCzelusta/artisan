# Minimal preferences

Status: ready-for-agent

## Summary

Implement low-risk display preferences without introducing workspace state.

## Depends On

- 03-open-and-render-existing-file

## User Value

Users can make the editor comfortable without turning Artisan into an IDE.

## Scope

- Font size preference.
- Theme preference if themes exist.
- Window size preference.
- No tab restore.
- No project/workspace restore.

## Acceptance Criteria

- Preferences persist across app launches.
- Previous tabs do not restore.
- Preferences do not materially affect launch performance.
- Benchmark gate passes.

## Verification

- Change preference, quit, reopen, confirm retained.
- Open files, quit, reopen app without args, confirm tabs are not restored.
- Run `scripts/run-benchmarks.sh`.

## Comments
