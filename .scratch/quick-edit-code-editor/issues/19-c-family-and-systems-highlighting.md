# C-family and systems highlighting

Status: ready-for-agent

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
