# Artisan

Artisan is a native macOS quick-edit code editor for developers who need a fast graphical editor during agent-assisted coding workflows.

## Language

**Quick-edit code editor**:
A lightweight editor optimized for opening one or more existing code files quickly, making small human edits, saving, and closing.
_Avoid_: IDE, rich text editor, project editor

**Agent-assisted coding workflow**:
A development workflow where an agent performs most repository changes and a human occasionally opens files directly to inspect or make focused edits.
_Avoid_: AI editor, agent IDE

**Editor session**:
The short-lived interaction that begins when a user opens files with Artisan and ends when they save or close the editor.
_Avoid_: Workspace, project

**Mostly stateless**:
An app behavior model where each editor session is defined by the current CLI invocation, with only low-risk preferences retained between launches.
_Avoid_: Workspace restore, project state

**Session tab**:
A file tab that belongs only to the current editor session. Session tabs can come from CLI arguments or from opening files inside the app, but they are not restored after the session ends.
_Avoid_: Workspace tab, project tab

**Large file**:
A source or text file large enough to stress editor responsiveness. In v1, 2 MB files must feel smooth, 10 MB files should open and scroll without beachballing, and larger files may degrade gracefully.
_Avoid_: Huge project, large workspace

**CLI invocation**:
A command-line request to open one or more existing files in Artisan. A CLI invocation may return immediately or block with `--wait`, but it never creates new files.
_Avoid_: New document command, workspace launch
