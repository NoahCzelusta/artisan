#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# This is the default local validation path. It avoids checks that intentionally
# launch, activate, or close the macOS app window.
export ARTISAN_QUIET_UI="${ARTISAN_QUIET_UI:-1}"

checks=(
  scripts/check-ci-workflows.sh
  scripts/check-open-source-readiness.sh
  scripts/check-production-targets.sh
  scripts/check-release-distribution-plan.sh
  scripts/check-product-spec.sh
  scripts/check-plain-text-rendering.sh
  scripts/check-edit-operations.sh
  scripts/check-save-operations.sh
  scripts/check-disk-change-save.sh
  scripts/check-keyboard-navigation.sh
  scripts/check-selection-model.sh
  scripts/check-selection-editing.sh
  scripts/check-undo-redo.sh
  scripts/check-find.sh
  scripts/check-native-menus.sh
  scripts/check-language-registry.sh
  scripts/check-typescript-javascript-highlighting.sh
  scripts/check-doc-data-highlighting.sh
  scripts/check-c-family-highlighting.sh
  scripts/check-web-scripting-highlighting.sh
  scripts/check-build-config-highlighting.sh
  scripts/check-horizontal-caret-visibility.sh
  scripts/check-minimal-preferences.sh
  scripts/check-local-install-packaging.sh
  scripts/check-release-package.sh
)

cd "$ROOT_DIR"
for check in "${checks[@]}"; do
  echo "==> $check"
  "$ROOT_DIR/$check"
done

echo "quiet local checks passed"
