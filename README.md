# Artisan

Artisan is a planned native macOS quick-edit code editor for developers who need a fast graphical editor during agent-assisted coding workflows.

The goal is simple: open existing files from the command line, make focused edits, save, and close without the startup cost or scope of a full IDE.

## Product Direction

- Native macOS app
- CLI-first workflow: `artisan file...`
- Blocking edit workflow: `artisan --wait file...`
- One primary window with session tabs
- Existing files only
- Mostly stateless sessions
- Conservative file saves
- No language servers, indexing, extensions, terminal, Git integration, or AI/chat integration

See [.scratch/quick-edit-code-editor/PRD.md](.scratch/quick-edit-code-editor/PRD.md) for the current product requirements.

## Performance Targets

- Cold launch to editable cursor: under 300ms
- Warm launch to editable cursor: under 100ms
- CLI overhead before app handoff: under 50ms
- 2 MB source/text files must feel smooth
- 10 MB source/text files should open and scroll without beachballing

## Documentation

- [CONTEXT.md](CONTEXT.md) defines the product language.
- [docs/adr/](docs/adr/) records architectural decisions.
- [AGENTS.md](AGENTS.md) configures agent workflows for this repo.

## Status

Pre-implementation. The repo currently contains product scope, agent setup, and architecture notes.
