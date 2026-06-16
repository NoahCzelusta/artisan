# Release Distribution

This project keeps local development, CI dry-runs, and trusted public
distribution separate. The MVP can stay repo-local through
`scripts/install-local.sh`; teammate distribution should move through signed,
notarized release artifacts before a Homebrew Cask becomes the default install
path.

## Current Artifact State

- `scripts/build-artisan-app.sh` produces `Artisan.app` under `.build/release`.
- `scripts/package-release.sh <version>` produces a versioned zip archive,
  checksum file, and generated Homebrew cask under `dist/` by default.
- `.github/workflows/ci.yml` runs functional gates and creates an uploadable
  release-package dry run on pull requests and pushes to `main`.
- `.github/workflows/release.yml` packages tag builds and publishes GitHub
  Release assets for `v*` tags.
- The current release app is a thin `arm64` bundle on this machine, not a
  universal binary.
- If no Developer ID identity is provided, release packages are ad hoc signed
  only. They are fine for CI validation and local testing, but not
  distribution-ready.
- Trusted teammate downloads still require Developer ID signing plus
  notarization.

## Target Release Path

1. Keep `scripts/install-local.sh` as the repo-local contributor install path.
2. Use `scripts/package-release.sh <version>` to build `Artisan.app` and the
   `artisan` CLI in release mode.
3. Sign both the app bundle and standalone CLI with a Developer ID Application
   certificate and hardened runtime.
4. Package the signed app bundle and sibling CLI binary into a versioned archive
   hosted on GitHub Releases.
5. Submit the archive with `notarytool`, staple the resulting ticket to the app
   with `stapler`, and validate the final artifact.
6. Publish a private Homebrew tap first.
7. Consider the official `homebrew-cask` repository only after the project has a
   public homepage/release history and enough notability to pass audit review.

The preferred first release artifact is:

```text
Artisan-v0.1.0-macos-arm64.zip
  Artisan.app
  artisan
```

When Intel support matters, switch this to either a universal archive or
architecture-specific archives. Homebrew Cask supports architecture-specific
URLs and checksums, but a universal archive is simpler for users if launch-time
and binary-size impact stay acceptable.

## CI

CI is configured through GitHub Actions:

- `scripts/run-ci.sh` runs the deterministic product, editor, highlighting,
  packaging, release-plan, and workflow checks.
- `.github/workflows/ci.yml` runs on pull requests, pushes to `main`, and manual
  dispatch. It builds release products, runs `scripts/run-ci.sh`, creates a
  release-package dry run, and uploads the zip/checksum/generated cask as a
  workflow artifact.
- `scripts/run-benchmarks.sh` remains the local product performance gate with
  the aggressive benchmark targets in `benchmarks/targets.env`.

CI intentionally does not require Developer ID signing secrets for every pull
request. The package check produces an ad hoc signed archive to validate bundle
shape, checksum generation, and Homebrew cask rendering.

## Release Packaging

Create a local dry-run package with:

```bash
ARTISAN_RELEASE_ALLOW_DIRTY=1 scripts/package-release.sh 0.1.0
scripts/check-release-package.sh
```

For an actual trusted release, run the package script from a clean worktree and
provide signing/notarization settings:

```bash
ARTISAN_CODESIGN_IDENTITY="Developer ID Application: <Team Name> (<Team ID>)" \
ARTISAN_NOTARY_KEYCHAIN_PROFILE="artisan" \
  scripts/package-release.sh 0.1.0
```

The script writes:

```text
dist/Artisan-v0.1.0-macos-arm64.zip
dist/Artisan-v0.1.0-macos-arm64.zip.sha256
dist/artisan.rb
```

Useful environment variables:

- `ARTISAN_DIST_DIR`: alternate output directory.
- `ARTISAN_RELEASE_REPOSITORY`: owner/repo used for generated GitHub release
  URLs; defaults to `NoahCzelusta/artisan`.
- `ARTISAN_RELEASE_URL`: fully override the generated cask URL.
- `ARTISAN_RELEASE_ARCH`: override the archive architecture label.
- `ARTISAN_BUILD_NUMBER`: override `CFBundleVersion`.
- `ARTISAN_CODESIGN_IDENTITY`: Developer ID identity for hardened-runtime
  signing. Without it, the script uses ad hoc signing.
- `ARTISAN_NOTARY_KEYCHAIN_PROFILE`: `notarytool` keychain profile. Without it,
  the script skips notarization.

## Signing And Notarization

Apple's outside-the-Mac-App-Store path uses Developer ID signing plus optional
notarization for user trust. Apple documents that generating a Developer ID
certificate requires Apple Developer Program membership, and Xcode's
notarization flow requires Developer ID distribution, hardened runtime, and a
Developer ID Application certificate.

Required before trusted teammate downloads:

- Apple Developer Program membership.
- Access for the Apple account holder or a role that can create Developer ID
  certificates and notarization credentials.
- Developer ID Application certificate.
- Hardened runtime enabled during signing.
- Notarization credentials for `xcrun notarytool`, preferably App Store Connect
  API key credentials rather than a personal password.
- A release script that validates every artifact before upload.

The release script performs this shape of work:

```bash
scripts/package-release.sh 0.1.0
```

The `sha256` used by Homebrew must be calculated after the final archive is
created, not before stapling changes the staged app bundle.

## Homebrew Cask Plan

Homebrew Cask is feasible for Artisan because the Cask Cookbook supports:

- `url` pointing at a `.zip`, `.dmg`, `.tgz`, or similar release artifact.
- `sha256` for the downloaded artifact.
- `app "Artisan.app"` to install the macOS app.
- `binary "artisan"` to link the CLI into `$(brew --prefix)/bin`.

For the private tap, `scripts/package-release.sh` generates `dist/artisan.rb`.
The first generated cask has this shape:

```ruby
cask "artisan" do
  version "0.1.0"
  sha256 "<generated-release-archive-sha256>"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: ">= :sonoma"

  app "Artisan.app"
  binary "artisan"
end
```

This matches the current CLI assumption that the executable lives next to
`Artisan.app` inside the staged artifact. After copying `dist/artisan.rb` into a
private tap, the cask must be tested with:

```bash
brew install --cask <tap>/artisan
artisan README.md
artisan --wait README.md
brew uninstall --cask artisan
brew audit --new --cask artisan
```

The official `homebrew-cask` repository should be a later step. Homebrew's
acceptable casks guidance says low-notability casks may be rejected from the
main repositories, while private taps remain supported for software a team
depends on.

## Tag Release Flow

To publish a release:

1. Ensure the worktree is clean and the benchmark gate passes.
2. Create and push a tag such as `v0.1.0`.
3. `.github/workflows/release.yml` packages the archive, checksum, and generated
   cask.
4. For tag pushes, the workflow creates a GitHub Release and uploads the release
   assets.
5. Copy `dist/artisan.rb` or the uploaded `artisan.rb` asset into the private
   Homebrew tap.

## Deferred Decisions

License decision: deferred. The repo intentionally has no license file yet per
the current project direction. Choose a license before any public release or
official Homebrew Cask submission.

Trusted signing credential setup: deferred until an Apple Developer Program
account, Developer ID Application certificate, and notary credentials are
available.

Universal binary support: deferred until Intel support matters for the team.

## Source References

- [Apple: Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [Apple: Upload a macOS app to be notarized](https://help.apple.com/xcode/mac/current/en.lproj/dev88332a81e.html)
- [GitHub Actions: Building and testing Swift](https://docs.github.com/actions/guides/building-and-testing-swift)
- [GitHub Actions: Store and share data with workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data)
- [Homebrew: Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew: Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [Homebrew: Adding Software to Homebrew](https://docs.brew.sh/Adding-Software-to-Homebrew)
