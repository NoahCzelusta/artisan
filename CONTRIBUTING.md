# Contributing

Artisan is public as a reference implementation and product example. External contributions are not currently supported.

If you want a similar editor, fork the repository or use `SPEC.md` as a prompt/specification for your own coding agent. You do not need to preserve this repo's implementation choices.

## Project Direction

The product boundary is intentional:

- Native macOS quick-edit editor.
- Existing-file CLI workflow.
- Fast launch and responsive large-file editing.
- No language servers, project indexing, extensions, terminal, Git UI, or AI/chat integration.

## Pull Requests

Pull requests are used for maintainer workflow because `main` is protected. Unsolicited external PRs may be closed without review.

## Issues

GitHub Issues are used as the maintainer project tracker. Public issues may be closed if they are support requests, broad feature requests, or requests to change the core product boundary.

## Building Your Own

Start with `SPEC.md`. It is written so another agent or developer can build an Artisan-like app independently.
