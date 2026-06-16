# Local install packaging

Status: ready-for-agent

## Summary

Provide a local installable app and CLI workflow for teammates.

## Depends On

- 15-native-menus-and-shortcut-routing
- 06-implement-cli-wait

## User Value

Teammates can try Artisan without understanding the repo internals.

## Scope

- Build app bundle artifact.
- Install or symlink `artisan` CLI.
- Local install docs.
- Local uninstall docs.

## Acceptance Criteria

- User can install locally with documented command(s).
- `artisan file` launches installed app.
- `artisan --wait file` works from a normal shell.
- Uninstall removes app/CLI artifacts.
- Benchmark gate passes before packaging.

## Verification

- Perform local install.
- Run `artisan README.md`.
- Run `artisan --wait README.md`.
- Run uninstall and verify artifacts are removed.

## Comments
