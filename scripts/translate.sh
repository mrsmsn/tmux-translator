#!/usr/bin/env bash
# tmux-translator main script.
# Invoked via copy-pipe-and-cancel: receives the selection on stdin, translates
# it through the configured engine chain, and shows the result in a tmux popup.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

# Smallest popup that still reads well (wide enough for the header line).
readonly POPUP_MIN_WIDTH=24
readonly POPUP_MIN_HEIGHT=3

# load_engines <engines> -> sources each engine file that exists.
load_engines() {
  local eng
  for eng in $1; do
    if [ -f "$SCRIPT_DIR/engines/$eng.sh" ]; then
      # shellcheck source=/dev/null
      source "$SCRIPT_DIR/engines/$eng.sh"
    fi
  done
}

# detect_lang <text> <engines> -> first available engine's detected code.
detect_lang() {
  local text="$1" engines="$2" eng code
  for eng in $engines; do
    if declare -F "detect_$eng" >/dev/null; then
      if code="$("detect_$eng" "$text")" && [ -n "$code" ]; then
        printf '%s' "$code"
        return 0
      fi
    fi
  done
  return 1
}

# do_translate <text> <source> <target> <engines>
# Tries each engine in order; prints the first success, else fails with a
# summary on stderr (engine-level diagnostics are also forwarded to stderr).
do_translate() {
  local text="$1" source="$2" target="$3" engines="$4" eng out
  for eng in $engines; do
    if declare -F "translate_$eng" >/dev/null; then
      if out="$("translate_$eng" "$text" "$source" "$target")"; then
        printf '%s' "$out"
        return 0
      fi
    else
      echo "engine '$eng' is not defined" >&2
    fi
  done
  echo "All configured engines failed to translate." >&2
  return 1
}

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

  local engines source target target_alt use_cache clipboard width height
  engines="$(get_tmux_option @translate_engines 'trans google')"
  source="$(get_tmux_option @translate_source_lang 'auto')"
  target="$(get_tmux_option @translate_target_lang 'ja')"
  target_alt="$(get_tmux_option @translate_target_lang_alt 'en')"
  use_cache="$(get_tmux_option @translate_cache 'on')"
  clipboard="$(get_tmux_option @translate_clipboard 'off')"
  width="$(get_tmux_option @translate_popup_width '80%')"
  height="$(get_tmux_option @translate_popup_height '80%')"

  load_engines "$engines"

  # Cache key is computed from the *original* request so it stays stable even
  # when language detection (which may need the network) is unavailable later.
  local key resolved_target translated ok=0 err=""
  key="$(cache_key "$text" "$engines" "$source" "$target|$target_alt")"
  resolved_target="$target"

  if [ "$use_cache" = on ]; then
    local record
    if record="$(cache_get "$key")"; then
      # Stored as "<resolved-target>\n<translation>".
      resolved_target="${record%%$'\n'*}"
      translated="${record#*$'\n'}"
      ok=1
    fi
  fi

  if [ "$ok" -ne 1 ]; then
    # Language reversal: if auto-detected source equals target, flip to alt.
    if [ "$source" = auto ]; then
      local detected
      if detected="$(detect_lang "$text" "$engines")" && [ "$detected" = "$target" ]; then
        resolved_target="$target_alt"
      fi
    fi

    local errfile
    errfile="$(mktemp "${TMPDIR:-/tmp}/tmux-translate-err.XXXXXX")"
    if translated="$(do_translate "$text" "$source" "$resolved_target" "$engines" 2>"$errfile")"; then
      ok=1
      [ "$use_cache" = on ] && printf '%s\n%s' "$resolved_target" "$translated" | cache_set "$key"
    fi
    err="$(cat -- "$errfile")"
    rm -f -- "$errfile"
  fi

  local tmpfile
  tmpfile="$(mktemp "${TMPDIR:-/tmp}/tmux-translate.XXXXXX")"
  if [ "$ok" -eq 1 ]; then
    format_result "$text" "$translated" "$source" "$resolved_target" > "$tmpfile"
    if [ "$clipboard" = on ]; then
      local cb
      if cb="$(clipboard_cmd)"; then
        printf '%s' "$translated" | $cb 2>/dev/null || true
      fi
    fi
  else
    format_error "${err:-Translation failed.}" > "$tmpfile"
  fi

  # Size the popup to the content, capped at @translate_popup_{width,height}
  # (treated as maxima) and floored at a readable minimum.
  local rows cols client_w client_h max_w max_h popup_w popup_h
  read -r rows cols < <(text_dims "$tmpfile")
  client_w="$(tmux display-message -p '#{client_width}' 2>/dev/null)"
  client_h="$(tmux display-message -p '#{client_height}' 2>/dev/null)"
  client_w="${client_w:-80}"; client_h="${client_h:-24}"
  max_w="$(resolve_size "$width" "$client_w")"
  max_h="$(resolve_size "$height" "$client_h")"
  # +3 cols (border + margin), +3 rows (border + less prompt line).
  popup_w="$(clamp "$(( cols + 3 ))" "$POPUP_MIN_WIDTH" "$max_w")"
  popup_h="$(clamp "$(( rows + 3 ))" "$POPUP_MIN_HEIGHT" "$max_h")"

  tmux display-popup -w "$popup_w" -h "$popup_h" -E \
    "less -R -- '$tmpfile'; rm -f -- '$tmpfile'"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
