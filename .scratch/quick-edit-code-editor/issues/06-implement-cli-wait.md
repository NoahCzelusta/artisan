# Implement CLI wait

Status: done

## Summary

Implement `artisan --wait file...` so terminal workflows can block until editing is done.

## Depends On

- 05-implement-session-tabs

## User Value

Agent and Git-style workflows can launch Artisan as a blocking editor.

## Scope

- Invocation ids.
- Waiting on one or more tabs.
- Multiple waiters for the same tab.
- App quit releases waiters.
- Failed handoff exits non-zero.

## Acceptance Criteria

- `artisan --wait file` blocks until that tab closes.
- `artisan --wait file_a file_b` blocks until all files from that invocation close or app exits.
- If the file is already open, the waiter attaches to the existing tab.
- Multiple terminals can wait on the same open file.
- Missing file exits non-zero before app handoff.
- Benchmark gate passes.

## Verification

- Run `artisan --wait README.md`, close the tab, confirm shell resumes.
- Run two waiters for the same file, close the tab, confirm both resume.
- Run `scripts/run-benchmarks.sh`.

## Comments

- Added `scripts/check-cli-wait.sh` for automated `--wait` coverage: missing-file rejection, blocking behavior, and app-quit release.
- Made pending wait invocations track an explicit `remainingPaths` set so multi-file waits complete only after every path for that invocation closes.
- Set File menu targets explicitly so `Cmd-O`, `Cmd-S`, and `Cmd-W` route to `AppController` rather than relying on responder-chain lookup.
- Tightened cold CLI benchmark timing to use direct `wait` plus a watchdog instead of polling process completion.
- Verification:
  - `scripts/check-cli-wait.sh` passed.
  - Computer Use with a persistent shell confirmed `artisan --wait README.md CONTEXT.md` stayed blocked after closing the first tab and exited cleanly after closing the second tab.
  - Computer Use confirmed two separate `artisan --wait README.md` processes attached to the same tab and both exited when the tab/app closed.
  - `scripts/check-cli-open-existing-files.sh` passed.
  - `scripts/check-plain-text-rendering.sh` passed.
  - `scripts/check-production-targets.sh` passed.
  - `scripts/check-mvp-prd.sh` passed.
  - `scripts/run-benchmarks.sh` passed with cold CLI runs `214 208 232 218 215` ms.
