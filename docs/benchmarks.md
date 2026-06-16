# Benchmarks

Artisan's performance requirements are product requirements. The editor must stay fast after adding editing, highlighting, packaging, and real app features.

## Reproducible Command

Run the benchmark gate from the repo root:

```bash
scripts/run-benchmarks.sh
```

The runner:

- builds the release prototype
- generates deterministic 10 MiB fixtures under `.scratch/benchmark-fixtures/`
- runs the app benchmark mode against the TypeScript fixture
- measures cold CLI launch/open through `artisan-proto`
- checks results against `benchmarks/targets.env`

Generated fixtures are intentionally ignored by git.

## Targets

The machine-readable targets live in `benchmarks/targets.env`. The current product gates are:

| Metric | Target |
| --- | ---: |
| Cold CLI launch + 10 MiB open | `<250 ms` |
| App open to usable viewport | `<15 ms` |
| Immediate scrollbar-to-bottom render | `<25 ms` |
| Bottom render non-empty lines | `>=1` |
| Bottom scrollbar indexing | `>=1` scroll-triggered index |
| Draw-triggered indexing for bottom scroll | `0` |
| Full line index completion | `<35 ms` |
| Scroll average step | `<8 ms` |
| Navigation average move | `<8 ms` |
| Highlight average line | `<0.05 ms` |
| Insert average character | `<4 ms` |
| Delete average character | `<4 ms` |
| Newline average insert | `<8 ms` |
| 1 KiB paste | `<8 ms` |

These are user-path gates: they measure real scroll-view rendering and visible redraw work, not only editor-core state mutation. The non-blocking stretch target for repeated visible interactions remains `<2 ms` average where the implementation can achieve it without compromising correctness.

## Required Interaction Paths

Benchmarks must cover user paths, not only convenient internal APIs:

- CLI open of an existing file
- scrollbar drag to bottom immediately after open
- trackpad/mouse-wheel style scrolling
- keyboard navigation
- click-to-caret
- character insert
- delete/backspace
- newline insert
- paste
- viewport-bounded syntax highlighting

The scrollbar benchmark must use the `NSScrollView` clip-view path. A benchmark that calls only a document-view helper is not sufficient.

## Fixture Policy

Benchmark fixtures should be deterministic and generated locally:

- `large.ts`: TypeScript-like code with comments, strings, types, and exports
- `large.md`: Markdown text with code fences and prose
- `large.txt`: plain text

Each fixture is at least 10 MiB. Do not commit generated fixture files.

## Interpreting Failures

A benchmark failure means the current implementation is no longer satisfying the quick-edit product contract. Prefer fixing the architecture or benchmarked path over relaxing targets.

Targets can change only when we intentionally change the product contract and record why.
