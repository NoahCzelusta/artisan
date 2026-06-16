# Release Distribution

This project keeps local development, CI dry-runs, and public distribution
separate. The contributor path stays repo-local through
`scripts/install-local.sh`; the user-facing path goes through a same-repo
Homebrew cask backed by GitHub Release assets.

## Current Artifact State

- `scripts/build-artisan-app.sh` produces `Artisan.app` under `.build/release`.
- `scripts/package-release.sh <version>` produces a versioned zip archive,
  checksum file, and generated Homebrew cask under `dist/` by default.
- `.github/workflows/ci.yml` runs functional gates and creates an uploadable
  release-package dry run on pull requests and pushes to `main`.
- `.github/workflows/release.yml` packages tag builds, publishes GitHub Release
  assets for `v*` tags, and writes the generated cask to `Casks/artisan.rb` on
  `main`.
- The current release app is a thin `arm64` bundle on this machine, not a
  universal binary.
- If no Developer ID identity is provided, release packages are ad hoc signed
  only. The first public `0.0.1` release uses that path so the team can test the
  real Homebrew install flow before signing credentials are ready.
- Fully trusted teammate downloads still require Developer ID signing plus
  notarization.
- The `0.0.1` Homebrew install path has been verified, but macOS rejects normal
  launch while the installed app is quarantined and only ad hoc signed.

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
6. Publish `Casks/artisan.rb` in this same public repository.
7. Consider the official `homebrew-cask` repository only after the project has a
   public homepage/release history and enough notability to pass audit review.

The preferred first release artifact is:

```text
Artisan-v0.0.1-macos-arm64.zip
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
- `.github/workflows/release.yml` requires signing/notarization secrets,
  imports a Developer ID Application certificate into a temporary keychain,
  creates a temporary `artisan-ci` notary profile, packages the release, and
  validates Gatekeeper acceptance before publishing assets.
- `scripts/run-benchmarks.sh` remains the local product performance gate with
  the aggressive benchmark targets in `benchmarks/targets.env`.

CI intentionally does not require Developer ID signing secrets for every pull
request. The package check produces an ad hoc signed archive to validate bundle
shape, checksum generation, and Homebrew cask rendering.

## Release Packaging

Create a local dry-run package with:

```bash
ARTISAN_RELEASE_ALLOW_DIRTY=1 scripts/package-release.sh 0.0.1
scripts/check-release-package.sh
```

For an actual trusted release, run the package script from a clean worktree and
provide signing/notarization settings:

```bash
ARTISAN_CODESIGN_IDENTITY="Developer ID Application: <Team Name> (<Team ID>)" \
ARTISAN_NOTARY_KEYCHAIN_PROFILE="artisan" \
  scripts/package-release.sh 0.0.1
```

The script writes:

```text
dist/Artisan-v0.0.1-macos-arm64.zip
dist/Artisan-v0.0.1-macos-arm64.zip.sha256
dist/artisan.rb
```

Useful environment variables:

- `ARTISAN_DIST_DIR`: alternate output directory.
- `ARTISAN_RELEASE_REPOSITORY`: owner/repo used for generated GitHub release
  URLs; defaults to `NoahCzelusta/artisan`.
- `ARTISAN_RELEASE_URL`: fully override the generated cask URL.
- `ARTISAN_CASK_FILE`: alternate generated cask output path.
- `ARTISAN_RELEASE_ARCH`: override the archive architecture label.
- `ARTISAN_BUILD_NUMBER`: override `CFBundleVersion`.
- `ARTISAN_CODESIGN_IDENTITY`: Developer ID identity for hardened-runtime
  signing. Without it, the script uses ad hoc signing.
- `ARTISAN_NOTARY_KEYCHAIN_PROFILE`: `notarytool` keychain profile. Without it,
  the script skips notarization.
- `ARTISAN_NOTARY_KEYCHAIN`: optional keychain path to pass to `notarytool`.
  The release workflow uses this for its temporary signing keychain.

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
scripts/package-release.sh 0.0.1
```

The `sha256` used by Homebrew must be calculated after the final archive is
created, not before stapling changes the staged app bundle.

### GitHub Release Secrets

Tag releases require these repository secrets:

- `ARTISAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`: base64 of the exported
  Developer ID Application `.p12`.
- `ARTISAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`: password for that
  `.p12`.
- `ARTISAN_NOTARY_API_KEY_BASE64`: base64 of the App Store Connect API
  `AuthKey_*.p8` file.
- `ARTISAN_NOTARY_API_KEY_ID`: App Store Connect API key ID.
- `ARTISAN_NOTARY_API_ISSUER_ID`: App Store Connect API issuer UUID.

The release workflow stores the notary credentials as `artisan-ci` in a
temporary keychain for the duration of the job. Local proof builds can reuse an
existing local profile such as `flow-notary`; GitHub Actions cannot access local
Keychain profiles.

Export the Developer ID Application identity from Keychain Access, or with:

```bash
security export \
  -k "$HOME/Library/Keychains/login.keychain-db" \
  -t identities \
  -f pkcs12 \
  -o /tmp/artisan-developer-id-application.p12
```

Then set the secrets with:

```bash
base64 < /tmp/artisan-developer-id-application.p12 |
  gh secret set ARTISAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64 --repo NoahCzelusta/artisan
gh secret set ARTISAN_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD --repo NoahCzelusta/artisan

base64 < "$HOME/Downloads/App Store Connect Auth Key.p8" |
  gh secret set ARTISAN_NOTARY_API_KEY_BASE64 --repo NoahCzelusta/artisan
gh secret set ARTISAN_NOTARY_API_KEY_ID --repo NoahCzelusta/artisan
gh secret set ARTISAN_NOTARY_API_ISSUER_ID --repo NoahCzelusta/artisan
```

## Homebrew Cask Plan

Homebrew Cask is feasible for Artisan because the Cask Cookbook supports:

- `url` pointing at a `.zip`, `.dmg`, `.tgz`, or similar release artifact.
- `sha256` for the downloaded artifact.
- `app "Artisan.app"` to install the macOS app.
- `binary "artisan"` to link the CLI into `$(brew --prefix)/bin`.

For release builds, `scripts/package-release.sh` generates `dist/artisan.rb`.
The tag release workflow copies that exact file into `Casks/artisan.rb` on
`main`, preserving the checksum of the uploaded archive. The first generated
cask has this shape:

```ruby
cask "artisan" do
  version "0.0.1"
  sha256 "<generated-release-archive-sha256>"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
```

This matches the current CLI assumption that the executable lives next to
`Artisan.app` inside the staged artifact. After the workflow updates
`Casks/artisan.rb`, the install path must be tested with:

```bash
brew tap NoahCzelusta/artisan https://github.com/NoahCzelusta/artisan
brew install --cask NoahCzelusta/artisan/artisan
brew uninstall --cask NoahCzelusta/artisan/artisan
brew audit --new --cask NoahCzelusta/artisan/artisan
```

After trusted signing is in place, the launch path must also be tested with:

```bash
artisan README.md
artisan --wait README.md
```

The `0.0.1` verification result is:

- `brew install --cask NoahCzelusta/artisan/artisan` succeeds.
- `brew audit --cask NoahCzelusta/artisan/artisan` passes.
- `spctl --assess --type execute /Applications/Artisan.app` rejects the app
  because the build is not Developer ID signed/notarized.

The official `homebrew-cask` repository should be a later step. Homebrew's
acceptable casks guidance says low-notability casks may be rejected from the
main repositories, while project taps remain supported for software a team
depends on.

## Tag Release Flow

To publish a release:

1. Ensure the worktree is clean and the benchmark gate passes.
2. Create and push a tag such as `v0.0.1`.
3. `.github/workflows/release.yml` packages the archive, checksum, and generated
   cask.
4. For tag pushes, the workflow creates a GitHub Release and uploads the release
   assets.
5. The workflow commits the generated cask to `Casks/artisan.rb` on `main`.

## Deferred Decisions

License decision: deferred. The repo intentionally has no license file yet per
the current project direction. Choose a license before any broader public
announcement or official Homebrew Cask submission.

GitHub signing secret provisioning: pending until the Developer ID `.p12`
export, `.p12` password, and App Store Connect API key metadata are added as
repository secrets.

Universal binary support: deferred until Intel support matters for the team.

## Source References

- [Apple: Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [Apple: Upload a macOS app to be notarized](https://help.apple.com/xcode/mac/current/en.lproj/dev88332a81e.html)
- [GitHub Actions: Building and testing Swift](https://docs.github.com/actions/guides/building-and-testing-swift)
- [GitHub Actions: Store and share data with workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data)
- [Homebrew: Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)
- [Homebrew: Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [Homebrew: Adding Software to Homebrew](https://docs.brew.sh/Adding-Software-to-Homebrew)
