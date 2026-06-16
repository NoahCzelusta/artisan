# C-family and systems highlighting

Status: ready-for-human

## Summary

Implement shared highlighting for C-like and systems languages.

## Depends On

- 16-language-detection-and-highlighter-registry

## User Value

Common compiled languages receive useful lexical highlighting without per-language complexity.

## Scope

- C, C++, C#, Java, Go, Rust, Swift, Kotlin.
- Shared C-like lexical highlighter where practical.
- Per-language keyword sets.

## Acceptance Criteria

- Fixtures for each language highlight keywords, comments, strings, numbers, and punctuation.
- Language-specific keywords are distinguishable enough to be useful.
- Benchmark gate passes.

## Verification

- Open representative fixture for each supported language.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-c-family-highlighting.sh` with a red/green benchmark mode for C, C++, C#, Java, Go, Rust, Swift, and Kotlin fixtures.
- 2026-06-16: Implemented a shared line-local C-like lexer with comments, strings, numbers, punctuation, and per-language keyword sets.
- 2026-06-16: Routed `c`, `cpp`, `csharp`, `java`, `go`, `rust`, `swift`, and `kotlin` through the dedicated highlighter registry path.
- 2026-06-16: Updated `docs/syntax-highlighting.md` with the implemented C-like highlighter coverage.
- 2026-06-16: Focused gate passed with `benchmark.c_family_highlighting=PASS`.
- 2026-06-16: Full gates passed: C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `139 147 146 150 145` ms; immediate bottom render was `10.02` ms and highlight averaged `0.0113` ms per sampled line.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for visible C/C++/C#/Java/Go/Rust/Swift/Kotlin highlighting.
