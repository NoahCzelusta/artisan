# MVP manual QA

Status: ready-for-human

## Summary

Run a full manual QA pass before calling the MVP complete.

## Depends On

- 01-refresh-mvp-prd
- 02-create-production-app-with-benchmark-gate
- 03-open-and-render-existing-file
- 04-cli-open-existing-files
- 05-implement-session-tabs
- 06-implement-cli-wait
- 07-edit-visible-text
- 08-save-dirty-state-and-close-prompts
- 09-detect-disk-changes-before-save
- 10-keyboard-navigation
- 11-selection-model-and-rendering
- 12-selection-editing-and-clipboard
- 13-undo-redo
- 14-find-in-current-file
- 15-native-menus-and-shortcut-routing
- 16-language-detection-and-highlighter-registry
- 17-typescript-javascript-highlighting
- 18-markdown-json-yaml-plain-text-highlighting
- 19-c-family-and-systems-highlighting
- 20-web-scripting-and-query-highlighting
- 21-minimal-preferences
- 22-editor-core-tests
- 23-local-install-packaging
- 24-release-distribution-plan

## User Value

The MVP is verified through real user interactions, not only implementation assumptions.

## Scope

- Manual open/edit/save/close pass.
- Scrollbar, trackpad, click, keyboard, selection, clipboard, undo/redo, find.
- `--wait` terminal workflow.
- Large-file workflow.
- Benchmark gate.

## Acceptance Criteria

- Small and large file edit workflows pass.
- Immediate scrollbar-to-bottom works after open.
- Trackpad/mouse-wheel scrolling works.
- Click-to-caret works after scrolling.
- Keyboard navigation and shift selection work.
- Clipboard and undo/redo work.
- Find works.
- Save and disk-change prompts work.
- `artisan --wait` exits when tabs close.
- `scripts/run-benchmarks.sh` passes.

## Verification

- Complete the QA checklist in this issue's comments.
- Record benchmark output.

## Comments

- 2026-06-16: Prepared the final MVP human QA checklist. Automated gates are passing, but this issue cannot be completed by the agent because Computer Use consistently fails to capture the Artisan window with `cgWindowNotFound`.
- 2026-06-16: Latest full gate passed: release distribution plan, local install packaging, editor core, preferences, web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, PRD check, and benchmark gate.
- 2026-06-16: Latest benchmark gate passed with cold CLI open runs `139 146 149 152 151` ms; immediate bottom render was `9.21` ms and scroll averaged `4.9041` ms.
- 2026-06-16: After restarting the app and granting additional Computer Use permissions, Computer Use now captures the Artisan window, tab state, editor screenshot, and scroll bar values correctly.
- 2026-06-16: Direct Computer Use action tools still fail immediately after a successful state read with `Computer Use is not active for 'Artisan'`, so full manual QA remains `ready-for-human`.
- 2026-06-16: Agent smoke verification passed with macOS accessibility input plus Computer Use visual confirmation: edited and saved `/tmp/artisan-ui-qa-1781625198.txt` to show `UI-OK alpha`, opened `large.ts`, set the vertical scrollbar to bottom, and confirmed lines `68067...68090` render with TypeScript highlighting.
- 2026-06-16: Latest benchmark gate passed with cold CLI open runs `194 217 235 228 229` ms; immediate bottom render was `9.31` ms and scroll averaged `5.5916` ms.
- 2026-06-16: Latest full scripted checks passed: release distribution plan, local install packaging, editor core, preferences, web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, and PRD check.
- 2026-06-16: Direct Computer Use actions now work when the `app` argument is the exact bundle path returned by `get_app_state` (`/Users/noahczelusta/dev/artisan/.build/arm64-apple-macosx/release/Artisan.app/`). Verified `type_text`, `set_value`, and `scroll` against Artisan.
- 2026-06-16: Direct `type_text` changed `/tmp/artisan-cu-direct-1781626239.txt` to `CU-PATH alpha` and the saved file contents matched on disk.
- 2026-06-16: Direct Computer Use `set_value` moved the large TypeScript fixture to the bottom and direct Computer Use `scroll` moved it upward; screenshots showed bottom-region highlighted lines around `068054...068077`.
- 2026-06-16: Fixed `scripts/run-benchmarks.sh` cleanup to kill repo app-bundle `ArtisanApp --server` processes. This removed stale servers that caused a cold CLI outlier.
- 2026-06-16: Latest benchmark gate passed after cleanup fix with cold CLI open runs `224 199 204 214 202` ms; immediate bottom render was `9.73` ms and scroll averaged `5.5037` ms.
- 2026-06-16: Latest full scripted checks passed: release distribution plan, local install packaging, editor core, preferences, web/scripting highlighting, C-family highlighting, doc/data highlighting, TS/JS highlighting, language registry, native menus, find, undo/redo, selection editing/model, keyboard navigation, disk-change save protection, save operations, edit operations, CLI wait/open, plain text rendering, production targets, and PRD check.
- 2026-06-16: Added all-language large highlighting benchmark coverage. `scripts/check-all-language-highlighting-benchmarks.sh` generates one large fixture per supported language id and measures 1,000 steady-state highlighted lines through `TextBuffer.highlightedSegments`.
- 2026-06-16: `scripts/run-benchmarks.sh` now includes the all-language highlighting gate instead of benchmarking only the TypeScript fixture for syntax performance.
- 2026-06-16: Latest full scripted checks passed with the all-language gate included. `scripts/run-benchmarks.sh` passed with cold CLI open runs `190 206 202 210 222` ms; immediate bottom render was `10.43` ms, scroll averaged `5.5827` ms, and all 26 language ids passed with worst highlight average `0.0198` ms/line for TypeScript.
- 2026-06-16: Added a production-target guard so `scripts/check-production-targets.sh` fails if `scripts/run-benchmarks.sh` stops invoking the all-language highlighting gate. Final focused re-run passed with cold CLI open runs `207 205 190 198 203` ms and worst all-language highlight average `0.0200` ms/line for TypeScript.
- 2026-06-16: Added regression coverage for Makefile, Dockerfile, XML, and TOML dedicated highlighting via `scripts/check-build-config-highlighting.sh`.
- 2026-06-16: Added regression coverage for long-line horizontal caret reveal, click placement after horizontal scroll, and current-line highlight coverage via `scripts/check-horizontal-caret-visibility.sh`.
- 2026-06-16: Latest benchmark gate passed after these regressions with cold CLI open runs `188 207 197 224 205` ms; all 26 language ids passed with worst highlight average `0.0200` ms/line for TypeScript. Computer Use visually confirmed Makefile, Dockerfile, XML, TOML, and long-line TypeScript tabs; direct Computer Use actions were blocked, so Command-Right/click input used macOS System Events with Computer Use screenshots for verification.

### Human QA checklist

- [ ] Install locally with `scripts/install-local.sh`.
- [ ] Open a small existing file with `artisan README.md`; confirm it opens in the installed app.
- [ ] Edit visible text, save with Command-S, close the tab, and confirm the file changed on disk.
- [ ] Run `artisan --wait README.md` from a normal shell; close the tab and confirm the shell command exits.
- [ ] Open a large TypeScript fixture and immediately drag the scrollbar to the bottom; confirm lines render without freezing.
- [ ] Scroll with trackpad or mouse wheel; confirm smooth incremental rendering.
- [ ] Click into the editor before and after scrolling; confirm caret placement works.
- [ ] Open a long single-line TypeScript file; press Command-Right and confirm the horizontal viewport scrolls so the caret remains visible.
- [ ] Horizontally scroll a long line, click in the editor, and confirm the caret appears at the clicked position.
- [ ] Horizontally scroll a long line and confirm the current-line highlight remains visible across the scrolled viewport.
- [ ] Exercise Option-arrow, Command-arrow, Shift-arrow, Shift-Option-arrow, and Shift-Command-arrow selection/navigation.
- [ ] Copy, cut, paste, undo, and redo selected text.
- [ ] Use find in the current file, including a match near the bottom of a large file.
- [ ] Modify the same file externally while dirty in Artisan; confirm the disk-change protection appears before saving.
- [ ] Open TypeScript, JavaScript, Python, Java, C, C++, C#, Go, Rust, PHP, Ruby, Swift, Kotlin, SQL, HTML, CSS, shell, JSON, YAML, R, Markdown, Makefile, Dockerfile, XML, TOML, and plain text samples; confirm highlighting is acceptable and unsupported files fall back to plain text.
- [ ] Run `scripts/uninstall-local.sh`; confirm app and CLI artifacts are removed.
