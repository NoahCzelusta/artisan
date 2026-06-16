# Create production app with benchmark gate

Status: done

## Summary

Create the production macOS app and CLI targets, then move the benchmark gate to those targets immediately.

## Depends On

- 01-refresh-mvp-prd

## User Value

Every subsequent feature is built in the real app and protected by performance benchmarks from the start.

## Scope

- Create production macOS app target.
- Create production CLI target named `artisan`.
- Keep or remove the prototype only after equivalent production behavior exists.
- Update `scripts/run-benchmarks.sh` to run against production artifacts.
- Document local build/run commands.

## Acceptance Criteria

- Production app launches.
- Production CLI can launch or focus the app.
- Benchmark runner targets production app/CLI.
- `scripts/run-benchmarks.sh` passes.
- README documents how to build, run, and benchmark.

## Verification

- Run `swift build -c release`.
- Run `scripts/run-benchmarks.sh`.
- Run `artisan` with no args and confirm it prints usage or opens the app according to the chosen behavior.

## Comments

- Completed production target rename to `ArtisanApp` and `artisan`.
- Added `scripts/check-production-targets.sh` as the issue gate.
- Added `scripts/build-artisan-app.sh` to stage `.build/release/Artisan.app`.
- Added `script/build_and_run.sh` and `.codex/environments/environment.toml` for a local bundled run path.
- Fixed bundled launch arguments to use absolute file paths because `open` does not preserve the shell working directory.
- Verification:
  - `scripts/check-production-targets.sh` passed.
  - `scripts/check-mvp-prd.sh` passed.
  - `swift build -c release` passed.
  - `.build/release/artisan` with no args returned usage and exit 64.
  - `script/build_and_run.sh --verify README.md` passed.
  - Computer Use confirmed a foreground `Artisan` app window with a `README.md` tab and rendered file content.
  - `scripts/run-benchmarks.sh` passed with cold CLI runs `220 221 223 224 216` ms.
