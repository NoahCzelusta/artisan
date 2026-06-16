# Artisan Product Spec

This document is a pasteable implementation spec for building an Artisan-like app from scratch. It describes the product contract, not this repository's internal implementation details.

## Summary

Build a native macOS quick-edit code editor for developers who need a fast graphical editor during agent-assisted coding workflows.

The app opens existing files from a command-line invocation, lets a human make focused edits, saves safely, and closes without becoming an IDE.

## Target User

- Developers who primarily work with coding agents.
- Developers who want a fast graphical editor but do not want Vim, a TUI, or a full IDE for quick edits.
- Teams that need a small native macOS editor that can be installed and launched from shell workflows.

## Core Product Contract

- Native macOS app.
- CLI-first workflow: `artisan file...`.
- Blocking editor workflow: `artisan --wait file...`.
- One primary window.
- One tab per opened file.
- Existing files only.
- Mostly stateless sessions.
- Safe saves.
- Fast launch and large-file responsiveness are product requirements.

## Non-Goals

Do not build:

- Project or workspace management.
- Folder sidebar or repository explorer.
- Language servers.
- Project indexing.
- Extension or plugin system.
- Integrated terminal.
- Git UI.
- AI/chat integration.
- New-file creation from the app or CLI.
- Whole-project formatting.
- Semantic highlighting that requires project analysis.

## CLI

The CLI must support:

```bash
artisan file
artisan file_a file_b
artisan --wait file
artisan --wait file_a file_b
```

Requirements:

- Resolve paths relative to the shell current working directory before handoff.
- Reject missing files.
- Reject directories.
- Never create an unsaved buffer for a missing path.
- Without `--wait`, launch or focus Artisan, open requested files as tabs, then exit.
- With `--wait`, block until every file from that invocation closes, or until the app exits.
- If the app is already open, a new invocation adds or focuses tabs in the existing window.
- If a requested file is already open, focus the existing tab instead of duplicating it.
- CLI overhead before app handoff should be under 50 ms.

## Editor Session

- The app has one primary window.
- Each opened file appears as a session tab.
- Session tabs can come from CLI arguments or a native open-file command.
- Closing the app ends the session.
- Do not restore previous tabs automatically.
- Low-risk preferences may persist, such as font size, theme, and window size.
- Do not persist workspace or project state.

## File Editing

Support UTF-8 text/source files.

Requirements:

- Open existing files.
- Edit visible text.
- Save with `Cmd-S`.
- Track dirty state per tab.
- Prompt before closing dirty tabs or dirty windows.
- Detect if a file changed on disk after it was opened.
- On external disk change, offer reload, save anyway, or cancel.
- Save atomically.
- Preserve line endings where possible.
- Preserve final newline presence where possible.
- Unsupported encodings or binary-looking files should fail or open read-only rather than risk corruption.

## Basic Editor UX

- Native macOS window behavior.
- Monospace editing surface.
- Line numbers.
- Current-line highlight.
- Sticky line-number gutter during horizontal scroll.
- Click moves the caret.
- Double-click selects a word.
- Mouse drag selects text.
- Basic find within the current file.
- Standard macOS menu items and shortcuts where applicable.
- No command palette required.
- No settings UI required beyond minimal native preferences.

## Keyboard Navigation And Selection

Navigation:

- Left / Right: move by character, crossing line boundaries.
- Up / Down: move by visual/text line while preserving preferred column where possible.
- Option-Left / Option-Right: move by word.
- Command-Left / Command-Right: move to line boundaries.
- Command-Up / Command-Down: move to file boundaries.
- Page Up / Page Down: move by viewport.
- Home / End: move to current-line boundaries.
- Ctrl-Tab / Ctrl-Shift-Tab: cycle session tabs and wrap around.

Selection:

- Shift-modified navigation extends selection.
- Selection supports copy, cut, delete, paste replacement, and typed replacement.
- Undo and redo cover MVP edit operations.

## Syntax Highlighting

Syntax highlighting must stay subordinate to launch speed, editing latency, and scrolling.

Rules:

- Highlight the visible viewport first.
- Do not parse or highlight an entire large file on open.
- Do not start language servers.
- Do not index a project or workspace.
- Use bounded lexical highlighters.
- Unknown or expensive files degrade safely to plain text.
- Multi-line language state is allowed only when bounded and incrementally recoverable.

Initial language and format coverage:

- TypeScript: `.ts`, `.tsx`, `.mts`, `.cts`
- JavaScript: `.js`, `.jsx`, `.mjs`, `.cjs`
- Python: `.py`, `.pyi`
- Java: `.java`
- C: `.c`, `.h`
- C++: `.cc`, `.cpp`, `.cxx`, `.hpp`, `.hh`, `.hxx`
- C#: `.cs`
- Go: `.go`
- Rust: `.rs`
- PHP: `.php`, `.phtml`
- Ruby: `.rb`, `.rake`, `Gemfile`
- Swift: `.swift`
- Kotlin: `.kt`, `.kts`
- SQL: `.sql`
- HTML: `.html`, `.htm`
- CSS: `.css`, `.scss`, `.sass`, `.less`
- Shell: `.sh`, `.bash`, `.zsh`, `.fish`, common shell shebangs
- JSON: `.json`, `.jsonc`
- YAML: `.yml`, `.yaml`
- R: `.r`
- Markdown: `.md`, `.mdx`, `.markdown`
- Makefile: `Makefile`, `GNUmakefile`
- Dockerfile: `Dockerfile*`
- XML: `.xml`
- TOML: `.toml`
- Plain text: `.txt`, unknown files

## Performance Requirements

Performance targets should be enforced with reproducible benchmarks.

- Cold CLI launch plus 10 MiB file open: under 250 ms.
- App open to usable viewport: under 15 ms.
- Immediate scrollbar-to-bottom render: under 25 ms.
- Full line index completion for a 10 MiB fixture: under 35 ms.
- Scroll average step: under 8 ms.
- Keyboard navigation average move: under 8 ms.
- Highlight average line: under 0.05 ms.
- Insert average character: under 4 ms.
- Delete average character: under 4 ms.
- Newline insertion: under 8 ms.
- 1 KiB paste: under 8 ms.
- Bottom-of-file insert plus delete: under 12 ms.

Required benchmark paths:

- CLI open of an existing file.
- Immediate scrollbar drag to bottom after open.
- Trackpad or mouse-wheel style scrolling.
- Keyboard navigation.
- Click-to-caret.
- Horizontal caret reveal on long lines.
- Sticky line numbers in horizontally scrolled viewports.
- Tab cycling and overflow tabs.
- Insert, delete, newline, paste.
- Edit near the bottom of a 10 MiB file.
- Viewport-bounded highlighting.
- Large-fixture highlighting for every supported language id.

## Packaging And Distribution

The preferred macOS distribution path:

- Build a native `.app` bundle and sibling `artisan` CLI.
- Sign the app and CLI with Developer ID Application.
- Use hardened runtime.
- Notarize release archives with `notarytool`.
- Staple the notarization ticket to the app.
- Validate with `codesign`, `stapler`, and `spctl`.
- Publish a versioned zip archive and checksum.
- Provide a Homebrew Cask that installs both `Artisan.app` and `artisan`.

## Acceptance Criteria

A build satisfies this spec when:

- `artisan README.md` opens an existing file in a native macOS window.
- `artisan --wait README.md` blocks until the corresponding tab closes.
- Missing files and directories fail before app handoff.
- Multiple files open as tabs in one primary window.
- Tabs are not restored automatically after quit/relaunch.
- A user can edit, save, and close a file safely.
- Dirty close prompts prevent accidental data loss.
- External disk changes are detected before overwrite.
- Keyboard navigation and selection follow macOS expectations.
- Syntax highlighting covers the listed languages without whole-file startup work.
- Large text/source files remain responsive under the benchmark targets.
- The app avoids every listed non-goal.

## Recommended Implementation Approach

Prefer native macOS APIs. A Swift app with AppKit-backed text/editor rendering is a good fit because it can launch quickly, integrate with macOS menus/windows, and avoid webview or IDE-scale overhead.

Use SwiftUI only where it does not compromise startup or editing performance. Keep any AppKit interop explicit and narrow.

Do not use a language-server-based editor core such as Monaco for this product contract.
