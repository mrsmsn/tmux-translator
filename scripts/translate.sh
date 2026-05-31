#!/usr/bin/env bash
# tmux-translator entry stage.
# Invoked via copy-pipe-and-cancel: receives the selection on stdin and opens a
# tmux popup that performs the translation. The work happens inside the popup
# (see scripts/render.sh) so a loading state is visible while the backend
# request is in flight.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

# Smallest popup that still reads well (wide enough for the header line).
readonly POPUP_MIN_WIDTH=24
readonly POPUP_MIN_HEIGHT=3

# trim leading/trailing whitespace (incl. newlines).
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

main() {
  local text
  text="$(trim "$(cat)")"
  [ -n "$text" ] || exit 0

  local width height
  width="$(get_tmux_option @translate_popup_width '80%')"
  height="$(get_tmux_option @translate_popup_height '80%')"

  local txtfile
  txtfile="$(mktemp "${TMPDIR:-/tmp}/tmux-translate-src.XXXXXX")"
  printf '%s' "$text" > "$txtfile"

  # The result (original + translation) is not known yet, so estimate the popup
  # size from the source selection: the result shows the source plus a
  # similar-length translation and a couple of header lines.
  local srows scols est_rows est_cols
  read -r srows scols < <(text_dims "$txtfile")
  est_rows=$(( srows * 2 + 3 ))
  est_cols=$scols
  [ "$est_cols" -lt "$POPUP_MIN_WIDTH" ] && est_cols=$POPUP_MIN_WIDTH

  local client_w client_h max_w max_h popup_w popup_h
  client_w="$(tmux display-message -p '#{client_width}' 2>/dev/null)"
  client_h="$(tmux display-message -p '#{client_height}' 2>/dev/null)"
  client_w="${client_w:-80}"; client_h="${client_h:-24}"
  max_w="$(resolve_size "$width" "$client_w")"
  max_h="$(resolve_size "$height" "$client_h")"
  # +3 cols (border + margin), +3 rows (border + pager prompt line).
  popup_w="$(clamp "$(( est_cols + 3 ))" "$POPUP_MIN_WIDTH" "$max_w")"
  popup_h="$(clamp "$(( est_rows + 3 ))" "$POPUP_MIN_HEIGHT" "$max_h")"

  tmux display-popup -w "$popup_w" -h "$popup_h" -E \
    "'$SCRIPT_DIR/render.sh' '$txtfile'"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
