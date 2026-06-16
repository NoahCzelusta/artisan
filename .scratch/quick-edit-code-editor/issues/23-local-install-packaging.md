# Local install packaging

Status: ready-for-human

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

- 2026-06-16: Added `scripts/install-local.sh`, `scripts/uninstall-local.sh`, and `scripts/check-local-install-packaging.sh`.
- 2026-06-16: Local install uses `ARTISAN_INSTALL_ROOT` defaulting to `~/.local/share/artisan` and `ARTISAN_BIN_DIR` defaulting to `~/.local/bin`; the wrapper execs the installed CLI binary so it can resolve the adjacent `Artisan.app` bundle.
- 2026-06-16: Uninstall removes only the installed app bundle, installed CLI binary, and wrapper files marked as owned by the Artisan local installer.
- 2026-06-16: Documented local install, normal open, `--wait`, environment overrides, and uninstall in `README.md`.
- 2026-06-16: Focused gate passed with `scripts/check-local-install-packaging.sh`.
- 2026-06-16: Full gates passed: local install packaging, editor core, preferences, web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `141 158 150 153 155` ms; immediate bottom render was `15.64` ms and scroll averaged `4.7947` ms.
- 2026-06-16: Computer Use listed Artisan as running but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for visible local install launch and `--wait` behavior from a normal shell.
