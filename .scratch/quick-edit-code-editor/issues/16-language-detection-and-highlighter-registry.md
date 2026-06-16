# Language detection and highlighter registry

Status: ready-for-human

## Summary

Implement language detection and a registry for viewport-bounded highlighters.

## Depends On

- 03-open-and-render-existing-file

## User Value

Files can be highlighted by language without adding language-server or project overhead.

## Scope

- Extension-based detection.
- Special filename detection.
- Shebang detection for scripts.
- Highlighter protocol/interface.
- Registry lookup.
- Plain text fallback.

## Acceptance Criteria

- Known extensions map to documented language ids.
- Unknown files use plain text.
- Detection does not inspect projects.
- Highlighting remains viewport-bounded.
- Benchmark gate passes.

## Verification

- Add detection tests or smoke fixtures for representative file names.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-language-registry.sh` with a red/green benchmark mode for extension detection, special filename detection, shebang detection, unknown-file fallback, and highlighter registry fallback.
- 2026-06-16: Implemented stable language ids, extension maps for the documented initial coverage set, special-name detection for Makefile/Dockerfile/Gemfile/Rakefile/shell rc files, and first-line shebang detection for common script runtimes.
- 2026-06-16: Added a `LineHighlighter` protocol and `HighlighterRegistry`; TypeScript/JavaScript use the current lexical highlighter, while other known languages intentionally fall back to plain text until their dedicated issues land.
- 2026-06-16: Updated `docs/syntax-highlighting.md` with the registry contract and plain fallback rules.
- 2026-06-16: Focused gate passed with `benchmark.language_registry=PASS`; it checked 8 representative fixtures and highlighted only one line per fixture.
- 2026-06-16: Full gates passed: language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `147 163 148 156 157` ms; immediate bottom render was `9.77` ms and scroll averaged `5.7322` ms.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for visually opening representative known-language and unknown-language files.
