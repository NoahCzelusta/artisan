# Language detection and highlighter registry

Status: ready-for-agent

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
