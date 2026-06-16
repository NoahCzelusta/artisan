# Release Distribution

This project should keep local development and public distribution separate.
The MVP can stay repo-local through `scripts/install-local.sh`; teammate
distribution should move through signed, notarized release artifacts before a
Homebrew Cask becomes the default install path.

## Current Artifact State

- `scripts/build-artisan-app.sh` produces `Artisan.app` under `.build/release`.
- The current release app is a thin `arm64` bundle on this machine, not a
  universal binary.
- Current local artifacts are ad hoc signed only. They are fine for development
  and local testing, but not distribution-ready.
- A pre-release Gatekeeper check currently fails on the local artifact, so we
  should not hand this bundle to teammates as a trusted download.

## Target Release Path

1. Keep `scripts/install-local.sh` as the repo-local contributor install path.
2. Add a release packaging script that builds `Artisan.app` and the `artisan`
   CLI in release mode.
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

The release script should eventually perform this shape of work:

```bash
VERSION="0.1.0"
ARCHIVE="dist/Artisan-v${VERSION}-macos-arm64.zip"
STAGE="$(mktemp -d)"

scripts/build-artisan-app.sh
ditto .build/release/Artisan.app "$STAGE/Artisan.app"
install -m 0755 .build/release/artisan "$STAGE/artisan"

codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <Team Name> (<Team ID>)" \
  "$STAGE/Artisan.app"
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <Team Name> (<Team ID>)" \
  "$STAGE/artisan"

ditto -c -k --sequesterRsrc "$STAGE" "$ARCHIVE"
xcrun notarytool submit "$ARCHIVE" --keychain-profile artisan --wait
xcrun stapler staple "$STAGE/Artisan.app"
xcrun stapler validate "$STAGE/Artisan.app"
codesign --verify --deep --strict --verbose=2 "$STAGE/Artisan.app"
spctl -a -vv --type execute "$STAGE/Artisan.app"

ditto -c -k --sequesterRsrc "$STAGE" "$ARCHIVE"
shasum -a 256 "$ARCHIVE"
```

The `sha256` used by Homebrew must be calculated after the final archive is
created, not before stapling changes the staged app bundle.

## Homebrew Cask Plan

Homebrew Cask is feasible for Artisan because the Cask Cookbook supports:

- `url` pointing at a `.zip`, `.dmg`, `.tgz`, or similar release artifact.
- `sha256` for the downloaded artifact.
- `app "Artisan.app"` to install the macOS app.
- `binary "artisan"` to link the CLI into `$(brew --prefix)/bin`.

For the private tap, the first cask should look roughly like:

```ruby
cask "artisan" do
  version "0.1.0"
  sha256 "<release-archive-sha256>"

  url "https://github.com/<owner>/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/<owner>/artisan"

  app "Artisan.app"
  binary "artisan"
end
```

This matches the current CLI assumption that the executable lives next to
`Artisan.app` inside the staged artifact. The cask must be tested with:

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

## Deferred Decisions

License decision: deferred. The repo intentionally has no license file yet per
the current project direction. Choose a license before any public release or
official Homebrew Cask submission.

CI decision: deferred. The release plan should eventually run packaging,
signing dry-runs where possible, `brew audit`, and `scripts/run-benchmarks.sh`
in CI, but CI setup is explicitly out of scope for the current MVP slice.

## Source References

- [Apple: Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [Apple: Upload a macOS app to be notarized](https://help.apple.com/xcode/mac/current/en.lproj/dev88332a81e.html)
- [Homebrew: Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew: Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [Homebrew: Adding Software to Homebrew](https://docs.brew.sh/Adding-Software-to-Homebrew)
