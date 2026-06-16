# Add CI

Status: needs-triage

## Summary

Add CI once the implementation stack is chosen.

## Context

The GitHub scaffold intentionally skipped CI because there is not yet an app implementation stack. CI should be revisited once the repo has a buildable macOS app, CLI target, or package structure.

## Acceptance Criteria

- Add a GitHub Actions workflow appropriate for the chosen stack.
- Run formatting, build, and tests if available.
- Keep CI aligned with the launch-performance constraints in the ADRs.

## Comments
