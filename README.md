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

Run the reproducible benchmark gate with:

```bash
scripts/run-benchmarks.sh
```

Run the deterministic CI gate locally with:

```bash
scripts/run-ci.sh
```

Build and open a file with the production CLI:

```bash
swift build -c release
.build/release/artisan README.md
```

Build a local macOS app bundle and open a file directly:

```bash
scripts/build-artisan-app.sh
open -n .build/release/Artisan.app --args "$PWD/README.md"
```

For a single local build/run entrypoint, use:

```bash
script/build_and_run.sh README.md
```

Install the release app and CLI locally:

```bash
scripts/install-local.sh
artisan README.md
artisan --wait README.md
```

By default this installs `Artisan.app` and the real CLI binary under
`~/.local/share/artisan`, plus a PATH wrapper at `~/.local/bin/artisan`. Set
`ARTISAN_INSTALL_ROOT` or `ARTISAN_BIN_DIR` to override those paths. Uninstall
with:

```bash
scripts/uninstall-local.sh
```

Create a local release-package dry run:

```bash
ARTISAN_RELEASE_ALLOW_DIRTY=1 scripts/package-release.sh 0.0.1
scripts/check-release-package.sh
```

This writes a versioned macOS zip, checksum, and generated Homebrew cask under
`dist/` by default.

Install from the public Homebrew tap:

```bash
brew tap NoahCzelusta/artisan https://github.com/NoahCzelusta/artisan
brew install --cask NoahCzelusta/artisan/artisan
artisan README.md
artisan --wait README.md
```

The first public cask is intentionally ad hoc signed while Developer ID signing
and notarization remain deferred; see [docs/distribution.md](docs/distribution.md).

## Documentation

- [CONTEXT.md](CONTEXT.md) defines the product language.
- [docs/adr/](docs/adr/) records architectural decisions.
- [docs/benchmarks.md](docs/benchmarks.md) defines benchmark targets and measurement paths.
- [docs/distribution.md](docs/distribution.md) defines the release distribution path.
- [docs/syntax-highlighting.md](docs/syntax-highlighting.md) defines the initial highlighting coverage plan.
- [AGENTS.md](AGENTS.md) configures agent workflows for this repo.

## Status

MVP implementation is underway. The repo contains the native app, CLI, local
install path, benchmark gates, CI, and release-package dry runs.
