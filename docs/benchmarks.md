# Benchmarks

Artisan's performance requirements are product requirements. The editor must stay fast after adding editing, highlighting, packaging, and real app features.

## Reproducible Command

Run the benchmark gate from the repo root:

```bash
scripts/run-benchmarks.sh
```

The runner:

- builds the release app
- generates deterministic 10 MiB fixtures under `.scratch/benchmark-fixtures/`
- runs the app benchmark mode against the TypeScript fixture
- runs the all-language large highlighting benchmark across every supported language id
- runs focused highlighting checks for build/config formats: Makefile, Dockerfile, XML, and TOML
- runs the horizontal caret visibility regression for long lines, Command-Right, click placement, sticky line numbers, gutter-clipped caret drawing, and current-line highlighting
- runs the tab navigation regression for Ctrl-Tab wrapping and scrollable overflow tabs
- measures cold CLI launch/open through `artisan`
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
| All-language highlight average line | `<0.05 ms` for each language |
| Insert average character | `<4 ms` |
| Delete average character | `<4 ms` |
| Newline average insert | `<8 ms` |
| 1 KiB paste | `<8 ms` |
| Bottom-of-file insert + delete | `<12 ms` |

These are user-path gates: they measure real scroll-view rendering and visible redraw work, not only editor-core state mutation. The non-blocking stretch target for repeated visible interactions remains `<2 ms` average where the implementation can achieve it without compromising correctness.

## Required Interaction Paths

Benchmarks must cover user paths, not only convenient internal APIs:

- CLI open of an existing file
- scrollbar drag to bottom immediately after open
- trackpad/mouse-wheel style scrolling
- keyboard navigation
- click-to-caret
- horizontal caret reveal after Command-Right on a long line
- sticky line numbers in horizontally scrolled viewports
- caret drawing clipped out of the sticky line-number gutter
- current-line highlight in a horizontally scrolled viewport
- Ctrl-Tab and Ctrl-Shift-Tab through many open tabs
- scrollable tab overflow for one-window, many-file sessions
- character insert
- delete/backspace
- newline insert
- paste
- edit near the bottom of a 10 MiB file
- viewport-bounded syntax highlighting
- large-fixture syntax highlighting for every supported language id

The scrollbar benchmark must use the `NSScrollView` clip-view path. A benchmark that calls only a document-view helper is not sufficient.

## Fixture Policy

Benchmark fixtures should be deterministic and generated locally:

- `large.ts`: TypeScript-like code with comments, strings, types, and exports
- `large.md`: Markdown text with code fences and prose
- `large.txt`: plain text
- all-language highlighting fixtures: one generated large file per supported language id

Each fixture is at least 10 MiB. Do not commit generated fixture files.

## Interpreting Failures

A benchmark failure means the current implementation is no longer satisfying the quick-edit product contract. Prefer fixing the architecture or benchmarked path over relaxing targets.

Targets can change only when we intentionally change the product contract and record why.
