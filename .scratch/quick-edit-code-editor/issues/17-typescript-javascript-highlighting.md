# TypeScript and JavaScript highlighting

Status: ready-for-human

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

- 2026-06-16: Added `scripts/check-typescript-javascript-highlighting.sh` with a red/green benchmark mode for `.ts`, `.tsx`, and `.jsx` fixtures.
- 2026-06-16: Added token kinds to highlight segments so syntax behavior can be tested independently from NSColor equality.
- 2026-06-16: Extended the TypeScript/JavaScript line lexer for keywords, line comments, inline block comments, strings, numbers, punctuation, and simple JSX/TSX tag and attribute spans.
- 2026-06-16: Updated `docs/syntax-highlighting.md` with the implemented TS/JS highlighter categories.
- 2026-06-16: Focused gate passed with `benchmark.ts_js_highlighting=PASS`.
- 2026-06-16: Full gates passed: TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `141 151 150 148 149` ms; immediate bottom render was `9.21` ms and highlight averaged `0.0115` ms per sampled line.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for visible `.ts`, `.tsx`, and `.jsx` highlighting.
