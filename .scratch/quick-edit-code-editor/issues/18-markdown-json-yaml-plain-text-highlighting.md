# Markdown, JSON, YAML, and plain text highlighting

Status: ready-for-agent

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
