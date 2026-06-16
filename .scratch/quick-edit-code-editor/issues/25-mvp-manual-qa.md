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

### Human QA checklist

- [ ] Install locally with `scripts/install-local.sh`.
- [ ] Open a small existing file with `artisan README.md`; confirm it opens in the installed app.
- [ ] Edit visible text, save with Command-S, close the tab, and confirm the file changed on disk.
- [ ] Run `artisan --wait README.md` from a normal shell; close the tab and confirm the shell command exits.
- [ ] Open a large TypeScript fixture and immediately drag the scrollbar to the bottom; confirm lines render without freezing.
- [ ] Scroll with trackpad or mouse wheel; confirm smooth incremental rendering.
- [ ] Click into the editor before and after scrolling; confirm caret placement works.
- [ ] Exercise Option-arrow, Command-arrow, Shift-arrow, Shift-Option-arrow, and Shift-Command-arrow selection/navigation.
- [ ] Copy, cut, paste, undo, and redo selected text.
- [ ] Use find in the current file, including a match near the bottom of a large file.
- [ ] Modify the same file externally while dirty in Artisan; confirm the disk-change protection appears before saving.
- [ ] Open TypeScript, Markdown, JSON, YAML, C/C++, Swift, Python, Ruby, Go, Rust, Java, Kotlin, shell, SQL, HTML/CSS, PHP, Lua, TOML, and plain text samples; confirm highlighting is acceptable and unsupported files fail clearly.
- [ ] Run `scripts/uninstall-local.sh`; confirm app and CLI artifacts are removed.
