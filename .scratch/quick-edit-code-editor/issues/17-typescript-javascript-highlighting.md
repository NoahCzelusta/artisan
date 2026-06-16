# TypeScript and JavaScript highlighting

Status: ready-for-agent

## Summary

Implement production TypeScript and JavaScript highlighting.

## Depends On

- 16-language-detection-and-highlighter-registry

## User Value

The most important web/agent coding files get useful highlighting first.

## Scope

- `.ts`, `.tsx`, `.mts`, `.cts`
- `.js`, `.jsx`, `.mjs`, `.cjs`
- Keywords, comments, strings, numbers, punctuation.
- JSX/TSX mode if feasible in this slice.

## Acceptance Criteria

- TypeScript and JavaScript fixtures highlight visibly.
- Highlighting is viewport-bounded.
- No whole-file parse on open.
- Benchmark gate passes.

## Verification

- Open TS/JS/TSX fixtures manually.
- Run `scripts/run-benchmarks.sh`.

## Comments
