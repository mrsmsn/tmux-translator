#!/usr/bin/env bash
# TPM entry point for tmux-translator.
# Binds the configured key in copy-mode-vi to pipe the selection into the
# translate script.
set -euo pipefail

CURRENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"

main() {
  local tmux_version
  tmux_version="$(tmux -V 2>/dev/null || printf 'tmux 0.0')"
  if ! version_ge "$tmux_version" 3.2; then
    tmux display-message "tmux-translator: display-popup requires tmux >= 3.2 (found $tmux_version)"
  fi

  local key
  key="$(get_tmux_option @translate_key 'T')"
  tmux bind-key -T copy-mode-vi "$key" \
    send-keys -X copy-pipe-and-cancel "$CURRENT_DIR/scripts/translate.sh"
}

main
