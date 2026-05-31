#!/usr/bin/env bash
# tmux-translator popup stage.
# Runs inside `tmux display-popup`. Animates a spinner while the translation
# runs in the background, then displays the result in a pager.
# Argument: a file containing the (trimmed) source selection.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

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

# produce_result <text> <engines> <source> <target> <target_alt> <cache> <clipboard>
# Runs the full pipeline and prints the formatted result (or error) to stdout.
# Always exits 0 so a backgrounded call never trips the parent's set -e.
produce_result() {
  local text="$1" engines="$2" source="$3" target="$4" target_alt="$5" \
        use_cache="$6" clipboard="$7"

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

  if [ "$ok" -eq 1 ]; then
    format_result "$text" "$translated" "$source" "$resolved_target"
    if [ "$clipboard" = on ]; then
      local cb
      if cb="$(clipboard_cmd)"; then
        printf '%s' "$translated" | $cb 2>/dev/null || true
      fi
    fi
  else
    format_error "${err:-Translation failed.}"
  fi
  return 0
}

# spinner <pid> <message> : animate until <pid> exits, then clear the line.
spinner() {
  local pid="$1" msg="$2" i=0 cyan reset
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  cyan=$'\033[1;36m'; reset=$'\033[0m'
  tput civis 2>/dev/null || true                 # hide cursor
  # Print at least one frame so the loading state is always shown.
  printf '%s%s%s %s' "$cyan" "${frames[0]}" "$reset" "$msg"
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r%s%s%s %s' "$cyan" "${frames[i % ${#frames[@]}]}" "$reset" "$msg"
    i=$(( i + 1 ))
    sleep 0.1 2>/dev/null || true
  done
  printf '\r\033[K'                              # clear the spinner line
  tput cnorm 2>/dev/null || true                 # restore cursor
}

main() {
  local txtfile="$1" text
  text="$(cat -- "$txtfile")"
  rm -f -- "$txtfile"

  local engines source target target_alt use_cache clipboard pager
  engines="$(get_tmux_option @translate_engines 'trans google')"
  source="$(get_tmux_option @translate_source_lang 'auto')"
  target="$(get_tmux_option @translate_target_lang 'ja')"
  target_alt="$(get_tmux_option @translate_target_lang_alt 'en')"
  use_cache="$(get_tmux_option @translate_cache 'on')"
  clipboard="$(get_tmux_option @translate_clipboard 'off')"
  pager="$(get_tmux_option @translate_pager 'less -R')"

  load_engines "$engines"

  local resultfile pid
  resultfile="$(mktemp "${TMPDIR:-/tmp}/tmux-translate.XXXXXX")"
  produce_result "$text" "$engines" "$source" "$target" "$target_alt" \
    "$use_cache" "$clipboard" > "$resultfile" &
  pid=$!
  spinner "$pid" "Translating…"
  wait "$pid" 2>/dev/null || true

  # Show the result (loading line is gone); default pager "less -R".
  local pager_arr
  read -r -a pager_arr <<< "$pager"
  "${pager_arr[@]}" "$resultfile"
  rm -f -- "$resultfile"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
