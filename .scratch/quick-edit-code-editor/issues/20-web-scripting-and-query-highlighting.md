# Web, scripting, and query highlighting

Status: ready-for-human

## Summary

Implement remaining MVP highlighters for common scripting, web, and query files.

## Depends On

- 16-language-detection-and-highlighter-registry

## User Value

The editor covers a broad practical set of files developers open during quick edits.

## Scope

- Python.
- Ruby.
- PHP.
- Shell.
- SQL.
- HTML.
- CSS / SCSS / LESS.
- R.

## Acceptance Criteria

- Fixtures for each language highlight useful lexical categories.
- HTML/CSS/PHP degrade gracefully in embedded-language cases.
- Shell shebang detection works.
- Benchmark gate passes.

## Verification

- Open representative fixture for each supported language.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-web-scripting-highlighting.sh` with a red/green benchmark mode for Python, Ruby, PHP, shell shebang, SQL, HTML, CSS, and R fixtures.
- 2026-06-16: Implemented a shared line-local scripting lexer with per-language keyword sets for Python, Ruby, PHP, shell, and R.
- 2026-06-16: Implemented line-local SQL, HTML, and CSS highlighters, including graceful HTML/CSS/PHP lexical fallback without embedded-language parsing.
- 2026-06-16: Routed `python`, `ruby`, `php`, `shell`, `r`, `sql`, `html`, and `css` through the dedicated highlighter registry path and updated the Python shebang registry expectation.
- 2026-06-16: Updated `docs/syntax-highlighting.md` with implemented web/scripting/query highlighter coverage.
- 2026-06-16: Focused gate passed with `benchmark.web_scripting_highlighting=PASS`.
- 2026-06-16: Full gates passed: web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `144 146 145 150 146` ms; immediate bottom render was `9.04` ms and highlight averaged `0.0117` ms per sampled line.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for visible Python/Ruby/PHP/shell/SQL/HTML/CSS/R highlighting.
