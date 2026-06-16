---
name: cut-artisan-release
description: Cut signed and notarized Artisan macOS releases from this repository. Use when the user asks to cut, ship, publish, or verify a new Artisan release; create or push a v* tag; update the same-repo Homebrew cask; or prove an end-to-end Homebrew install.
---

# Cut Artisan Release

## Overview

Use the repo's tag-driven release path. A `v*` tag triggers `.github/workflows/release.yml`, which signs, notarizes, staples, validates, publishes a GitHub Release, and commits the generated Homebrew cask to `Casks/artisan.rb` on `main`.

## Guardrails

- Cut releases from `main` only.
- Do not release with a dirty worktree or unpushed commits.
- Run the local CI gate before pushing a release tag.
- Do not force-move, delete, or recreate a public tag unless the user explicitly approves that recovery path.
- If a tag release fails after publication begins, prefer fixing forward with the next patch version.
- Treat unrelated Homebrew trust warnings as warnings unless they block Artisan install or audit.
- Do not delete generic Homebrew caches. Only remove caches matching this repo's `Artisan-v*` release names when a from-scratch proof requires a fresh download.

## Release Workflow

1. Sync and inspect current release state.

```bash
git checkout main
git pull --ff-only
git fetch --tags origin
git status -sb
git tag --list 'v*' --sort=v:refname | tail -10
sed -n '1,24p' Casks/artisan.rb
```

2. Choose the version.

- Use the user's requested version if provided.
- Otherwise infer the next patch version from the highest `vMAJOR.MINOR.PATCH` tag.
- Use a leading `v` for the tag, for example `v0.0.4`.

3. Run the local gate.

```bash
scripts/run-ci.sh
```

Stop and fix failures before tagging.

4. Create and push the tag.

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

5. Watch the release workflow.

```bash
gh run list --repo NoahCzelusta/artisan --workflow Release --limit 5
gh run watch <run-id> --repo NoahCzelusta/artisan --exit-status
```

The successful run must include signed artifact validation, GitHub Release publication, and same-repo cask update.

6. Pull the generated cask commit.

```bash
git pull --ff-only
sed -n '1,24p' Casks/artisan.rb
```

Verify `Casks/artisan.rb` has the released version and sha256.

7. Inspect the GitHub Release.

```bash
gh release view vX.Y.Z --repo NoahCzelusta/artisan --json tagName,url,isDraft,isPrerelease,assets
```

Expect zip, `.zip.sha256`, and `artisan.rb` assets.

## Homebrew Proof

For a normal upgrade smoke test:

```bash
brew update
brew upgrade --cask noahczelusta/artisan/artisan || brew install --cask noahczelusta/artisan/artisan
artisan README.md
```

For a from-scratch proof:

```bash
osascript -e 'quit app "Artisan"' >/dev/null 2>&1 || true
brew uninstall --cask --force noahczelusta/artisan/artisan >/dev/null 2>&1 || true
brew untap noahczelusta/artisan >/dev/null 2>&1 || true
rm -rf /Applications/Artisan.app /opt/homebrew/Caskroom/artisan /opt/homebrew/bin/artisan

brew tap NoahCzelusta/artisan https://github.com/NoahCzelusta/artisan
brew install --cask noahczelusta/artisan/artisan
artisan README.md
```

Validate the installed app:

```bash
brew list --cask --versions artisan
readlink /opt/homebrew/bin/artisan
codesign --verify --deep --strict /Applications/Artisan.app
codesign --verify --strict /opt/homebrew/bin/artisan
xcrun stapler validate /Applications/Artisan.app
spctl --assess --type execute --verbose=4 /Applications/Artisan.app
brew audit --cask noahczelusta/artisan/artisan
brew developer off
```

`artisan README.md` must print `opened 1 file(s)`.

## Failure Handling

- Missing signing or notary secrets: fix GitHub Secrets, then rerun or cut a new patch release depending on whether artifacts were published.
- Workflow failure before release publication: inspect logs with `gh run view <run-id> --log-failed`.
- Cask update commit missing: confirm the run was triggered by a tag, not `workflow_dispatch`.
- Homebrew installs an older version: run `brew update`, retap the repo, and inspect `Casks/artisan.rb`.
- CLI cannot find `Artisan.app`: check `/opt/homebrew/bin/artisan` resolves into `/opt/homebrew/Caskroom/artisan/<version>/artisan` and rerun `scripts/check-cli-open-existing-files.sh`.

## Final Response

Report:

- Released version and GitHub Release URL.
- Release workflow run id and status.
- Whether the generated cask commit was pulled.
- Homebrew installed version.
- Results of `artisan README.md`, `stapler`, `spctl`, and `brew audit`.
- Any cleanup performed, such as quitting the app or turning Homebrew developer mode off.
