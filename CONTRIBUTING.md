# Contributing

Artisan is a native macOS quick-edit editor. The project optimizes for fast startup, predictable file editing, and a small product surface.

## Development Setup

Requirements:

- macOS 14 or newer
- Xcode command line tools with Swift 6
- Homebrew
- `ripgrep`

Build and run the production CLI:

```bash
swift build -c release
.build/release/artisan README.md
```

Build a local app bundle:

```bash
scripts/build-artisan-app.sh
open -n .build/release/Artisan.app --args "$PWD/README.md"
```

## Verification

Run the full local gate before opening or merging a PR:

```bash
scripts/run-ci.sh
```

For performance-sensitive changes, also run:

```bash
scripts/run-benchmarks.sh
```

## Pull Requests

- `main` is protected. Use pull requests for changes.
- PRs must pass the `SwiftPM checks` GitHub Actions gate before merging.
- Keep changes focused.
- Include verification in the PR description.
- Preserve the product boundary: no language servers, background indexing, extension system, terminal, Git UI, or AI/chat integration.
- Use `docs/adr/` for durable architecture decisions.
- Update `CONTEXT.md` when product language changes.

## Releases

Releases are tag-driven and documented in `docs/distribution.md`. Repo-local release instructions live in `skills/cut-artisan-release/SKILL.md`.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
