#!/usr/bin/env bash
# Single source of truth for CI checks. Runs shellcheck + bats.
# Used both by the justfile (via podman) and by GitHub Actions.
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

echo "==> shellcheck"
shellcheck \
  translate.tmux \
  scripts/translate.sh \
  scripts/render.sh \
  scripts/helpers.sh \
  scripts/engines/*.sh \
  tests/stubs/tmux tests/stubs/trans tests/stubs/curl \
  ci/run-checks.sh

echo "==> bats"
bats tests
