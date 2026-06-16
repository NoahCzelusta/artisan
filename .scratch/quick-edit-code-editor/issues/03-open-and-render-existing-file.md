# Open and render existing file

Status: done

## Summary

Implement the first production editor slice: open an existing file, render visible lines, scroll correctly, and move the caret by clicking.

## Depends On

- 02-create-production-app-with-benchmark-gate

## User Value

A user can open a file in the real app and inspect it without blank rendering or IDE overhead.

## Scope

- File-backed text buffer sufficient for read-only display.
- Viewport renderer with line numbers.
- Scrollbar and trackpad/mouse-wheel scrolling.
- Immediate scrollbar-to-bottom render path.
- Click-to-caret.
- No editing required in this issue.

## Acceptance Criteria

- Opening a 10 MiB text/source file renders the initial viewport.
- Dragging scrollbar to bottom immediately after open renders real lines.
- Trackpad/mouse-wheel scroll renders real lines.
- Clicking in the editor moves the caret to the clicked line/approximate column.
- Unknown text files render as plain text.
- Benchmark gate passes.

## Verification

- Run `scripts/run-benchmarks.sh`.
- Manually open a generated large fixture.
- Drag scrollbar to top, middle, and bottom.
- Click in visible text after scrolling.

## Comments

- Production app already had the viewport renderer, line numbers, scroll view integration, and click-to-caret path from the prototype.
- Added `scripts/check-plain-text-rendering.sh` after UI verification showed `.txt` files were incorrectly using the TypeScript highlighter.
- Added minimal language detection so `.ts`/`.tsx` use TypeScript highlighting and unknown files render as plain text.
- Verification:
  - Red: `scripts/check-plain-text-rendering.sh` initially timed out because no highlight benchmark mode existed.
  - Green: `scripts/check-plain-text-rendering.sh` passed with `benchmark.highlight_multi_segment_lines=0` for `large.txt`.
  - `scripts/check-production-targets.sh` passed.
  - `scripts/check-mvp-prd.sh` passed.
  - `scripts/run-benchmarks.sh` passed with cold CLI runs `221 223 220 224 220` ms.
  - Computer Use opened the bundled app with `large.ts`, drove the scrollbar to the bottom, and confirmed real bottom-of-file lines around `068066`.
  - Computer Use clicked in the editor at the bottom of the 10 MiB fixture and the scroll area stayed focused/responsive.
  - Computer Use reopened `large.txt` and confirmed the visible text renders plainly without TypeScript token colors.
