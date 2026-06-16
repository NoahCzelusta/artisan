# CLI open existing files

Status: done

## Summary

Implement `artisan file...` for existing files, including path validation and tab focusing.

## Depends On

- 03-open-and-render-existing-file

## User Value

A developer can open one or more existing files from an agent/terminal workflow.

## Scope

- Resolve paths relative to the shell current directory.
- Reject missing files and directories before app handoff.
- Open multiple files as session tabs.
- Focus existing tab if a file is already open.
- Add `Cmd-O` to add existing files during the session.

## Acceptance Criteria

- `artisan file` opens one existing file.
- `artisan file_a file_b` opens multiple files as session tabs.
- Missing files fail with a clear error.
- Directories fail with a clear error.
- Reopening an open file focuses the existing tab instead of duplicating it.
- Benchmark gate passes.

## Verification

- Run `artisan README.md`.
- Run `artisan README.md CONTEXT.md`.
- Run `artisan definitely-missing.ts` and confirm non-zero exit.
- Run `scripts/run-benchmarks.sh`.

## Comments

- Added `scripts/check-cli-open-existing-files.sh` for CLI path validation and app handoff behavior.
- Fixed the CLI launch path to prefer the executable inside the staged `Artisan.app` bundle when present, with a raw executable fallback for bare SwiftPM builds.
- Detached child process stdio so shell command substitutions and scripts do not hang on inherited app output pipes.
- Tightened cold CLI benchmark polling from 100 ms to 10 ms because a 250 ms gate needs finer timer granularity.
- Verification:
  - Red: `scripts/check-cli-open-existing-files.sh` initially failed because CLI launched the raw app executable and could hang while app-owned pipes stayed open.
  - Green: `scripts/check-cli-open-existing-files.sh` passed.
  - `scripts/check-plain-text-rendering.sh` passed.
  - `scripts/check-production-targets.sh` passed.
  - `scripts/check-mvp-prd.sh` passed.
  - `scripts/run-benchmarks.sh` passed with cold CLI runs `200 215 240 226 230` ms.
  - Computer Use confirmed `artisan README.md CONTEXT.md` opened two tabs in the bundled app.
  - Computer Use confirmed reopening `README.md` selected the existing tab and did not create a duplicate tab.
