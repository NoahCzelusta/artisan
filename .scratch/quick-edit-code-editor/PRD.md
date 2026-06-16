# Quick-Edit Code Editor PRD

## Summary

Artisan is a native macOS quick-edit code editor for developers who need a fast graphical editor during agent-assisted coding workflows. It is optimized for opening existing files nearly instantly, making focused human edits, saving, and closing without the overhead of an IDE.

## Problem

Developers working with coding agents often need to quickly inspect or edit individual files while staying outside a full IDE workflow. Existing graphical options such as VS Code, Cursor, and other full IDEs are powerful but slow and heavy for this use case. Terminal editors and TUIs are performant but not friendly for teammates who prefer native graphical interfaces.

The missing tool is a native macOS editor that starts almost instantly, opens specific files from the CLI, supports quick edits, and exits cleanly without background indexing, language servers, project state, or IDE-style features.

## Target Users

- Developers using agents as their primary coding workflow.
- Developers who want a fast graphical editor but do not want Vim, a TUI, or a full IDE.
- Teammates who need an easily installable macOS app for quick file edits.

## Product Goals

- Make opening an existing file from the command line feel instant.
- Support short-lived editor sessions with one window and tabs for the requested files.
- Provide a safe, native editing experience for code and text files.
- Keep the app intentionally smaller than an IDE.
- Be straightforward to distribute to teammates, eventually through Homebrew Cask.

## Non-Goals

- Replacing VS Code, Cursor, Xcode, or full IDEs.
- Project or workspace management.
- Folder sidebar or repository explorer.
- Language servers.
- Background indexing.
- Extension/plugin system.
- Integrated terminal.
- Git integration.
- AI/chat integration.
- Creating new files from the editor or CLI.
- Formatting in MVP.
- Syntax highlighting in MVP.

## MVP Requirements

### CLI

Artisan must provide a CLI command:

```bash
artisan file
artisan file_a file_b
artisan --wait file
artisan --wait file_a file_b
```

Requirements:

- Paths resolve relative to the shell's current working directory before handoff.
- All paths must point to existing files.
- Missing paths fail with an error and must not create unsaved buffers.
- Without `--wait`, the CLI launches or focuses Artisan, opens the requested files as session tabs, then exits.
- With `--wait`, the CLI blocks until all files from that invocation are closed, or until the app exits.
- If Artisan is already open, a new invocation adds the requested files as session tabs to the existing window.
- CLI overhead before app handoff should be under 50ms.

### Editor Session

- Artisan uses one primary window.
- Each opened file appears as a session tab.
- Session tabs can come from CLI arguments or `Cmd-O`.
- Closing the app ends the session.
- Previous tabs are not restored automatically.
- The app may remember low-risk preferences such as font size, theme, and window size.
- The app must not remember workspace/project state.

### File Editing

- Open and edit UTF-8 text/source files.
- Save with `Cmd-S`.
- Prompt before closing a tab or window with unsaved changes.
- Warn if a file changed on disk after it was opened.
- Save atomically.
- Preserve line endings where possible.
- Preserve final newline presence where possible.
- Binary-looking files or unsupported encodings should open read-only or fail rather than risk corruption.

### Basic Editor UX

- Native macOS window behavior.
- Monospace editing surface.
- Line numbers.
- Basic find within the current file.
- Standard macOS keyboard shortcuts where applicable.
- No folder sidebar.
- No command palette required for MVP.
- No settings UI required for MVP beyond any minimal native preferences needed for retained low-risk preferences.

### Performance

- Cold launch to editable cursor: under 300ms.
- Warm launch to editable cursor: under 100ms.
- CLI overhead before app handoff: under 50ms.
- No background work on launch except reading requested files.
- No network calls on launch.
- No indexing.
- No language server startup.
- 2 MB source/text files must open and edit smoothly.
- 10 MB source/text files should open and scroll without beachballing.
- Files larger than 10 MB may degrade gracefully.

## Fast Follow

- Syntax highlighting, only if it does not compromise startup or large-file performance.
- Multiple themes or a small theme preference.
- Font and font-size preferences.
- Open recent files.
- Homebrew Cask distribution.
- Optional explicit single-file formatting command.

## Open Questions

- Which native macOS technology stack best meets the startup and large-file constraints?
- What exact editing component should back the text view?
- Should unsupported encodings fail at open time or open read-only?
- What is the best implementation model for `--wait` when multiple CLI invocations share one app process?
- What packaging/signing/notarization path is required before Homebrew Cask distribution?

## Success Criteria

- A developer can run `artisan path/to/file`, edit, save, and close faster than it would take to open a full IDE.
- `artisan --wait path/to/file` works reliably in agent-assisted workflows.
- The app feels native and predictable to non-Vim users.
- The MVP does not include IDE features that compromise launch speed or scope.
- Large files in the defined target range remain responsive enough for quick edits.
