# MVP manual QA

Status: ready-for-agent

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
