# Web, scripting, and query highlighting

Status: ready-for-agent

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
