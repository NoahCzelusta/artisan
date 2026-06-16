# Markdown, JSON, YAML, and plain text highlighting

Status: ready-for-human

## Summary

Implement common documentation/data highlighters and plain text fallback.

## Depends On

- 16-language-detection-and-highlighter-registry

## User Value

Users can quickly inspect and edit docs/config/data files with appropriate highlighting or clean plain text.

## Scope

- Markdown / MDX.
- JSON / JSONC.
- YAML.
- Plain text no-op highlighter.

## Acceptance Criteria

- Markdown headings, code fences, inline code, links, and emphasis highlight reasonably.
- JSON strings, numbers, booleans, null, punctuation, and comments for JSONC highlight.
- YAML keys, strings, comments, and scalars highlight.
- Plain text has no syntax styling.
- Benchmark gate passes.

## Verification

- Open generated `.md`, `.json`, `.yaml`, and `.txt` fixtures.
- Run `scripts/run-benchmarks.sh`.

## Comments

- 2026-06-16: Added `scripts/check-doc-data-highlighting.sh` with a red/green benchmark mode for Markdown, JSONC, YAML, and plain text fixtures.
- 2026-06-16: Added highlight token kinds for headings, code, links, emphasis, keys, booleans, nulls, and scalars.
- 2026-06-16: Implemented line-local Markdown, JSON/JSONC, and YAML highlighters; plain text remains a one-segment no-op highlighter.
- 2026-06-16: Updated `docs/syntax-highlighting.md` with the implemented doc/data highlighter categories and updated the language registry benchmark expectations for Markdown/YAML dedicated highlighters.
- 2026-06-16: Focused gate passed with `benchmark.doc_data_highlighting=PASS`.
- 2026-06-16: Full gates passed: doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Benchmark gate passed with cold CLI open runs `140 156 155 149 152` ms; immediate bottom render was `12.34` ms and highlight averaged `0.0117` ms per sampled line.
- 2026-06-16: Computer Use could launch Artisan but `get_app_state` failed with `cgWindowNotFound` for both `Artisan` and `com.noahczelusta.Artisan`. Manual verification still needed for visible `.md`, `.jsonc`, `.yaml`, and `.txt` rendering.
