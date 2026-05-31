#!/usr/bin/env bash
# Shared helpers for tmux-translator.
# This file only defines functions; it has no side effects when sourced.

# get_tmux_option <option-name> <default>
# Reads a global tmux user option (e.g. @translate_engines), falling back to
# <default> when unset/empty.
get_tmux_option() {
  local option="$1" default="$2" value
  value="$(tmux show-options -gqv "$option" 2>/dev/null)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$default"
  fi
}

# version_ge <a> <b> -> succeeds when version a >= b (compares major.minor only).
version_ge() {
  local a b a1 a2 b1 b2
  a="$(printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  b="$(printf '%s' "$2" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  a1="${a%%.*}"; a2="${a#*.}"
  b1="${b%%.*}"; b2="${b#*.}"
  a1="${a1:-0}"; a2="${a2:-0}"; b1="${b1:-0}"; b2="${b2:-0}"
  if [ "$a1" -gt "$b1" ]; then return 0; fi
  if [ "$a1" -lt "$b1" ]; then return 1; fi
  [ "$a2" -ge "$b2" ]
}

# cache_dir -> prints the cache directory (honours $XDG_CACHE_HOME).
cache_dir() {
  printf '%s/tmux-translate' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

# _hash  (data on stdin) -> a hex digest, using whatever hasher is available
# (shasum on macOS, sha1sum on Linux, cksum as a last resort).
_hash() {
  if command -v shasum >/dev/null 2>&1; then
    shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    sha1sum | awk '{print $1}'
  else
    cksum | awk '{print $1 "_" $2}'
  fi
}

# cache_key <text> <engines> <source> <target> -> stable hash for a request.
cache_key() {
  printf '%s\037%s\037%s\037%s' "$1" "$2" "$3" "$4" | _hash
}

# cache_get <key> -> prints cached body, exit 0 on hit / non-zero on miss.
cache_get() {
  local f
  f="$(cache_dir)/$1"
  [ -s "$f" ] || return 1
  cat -- "$f"
}

# cache_set <key>  (body read from stdin)
cache_set() {
  local dir
  dir="$(cache_dir)"
  mkdir -p -- "$dir"
  cat > "$dir/$1"
}

# clipboard_cmd -> prints a stdin-consuming copy command, exit 1 if none found.
clipboard_cmd() {
  if command -v pbcopy >/dev/null 2>&1; then
    printf 'pbcopy'
  elif command -v wl-copy >/dev/null 2>&1; then
    printf 'wl-copy'
  elif command -v xclip >/dev/null 2>&1; then
    printf 'xclip -selection clipboard'
  elif command -v xsel >/dev/null 2>&1; then
    printf 'xsel --clipboard --input'
  else
    return 1
  fi
}

# format_result <src-text> <translated> <source-lang> <target-lang>
# Emits an ANSI-coloured "original / translation" view for the pager.
format_result() {
  local src="$1" dst="$2" slang="$3" tlang="$4"
  local cyan green reset
  cyan=$'\033[1;36m'; green=$'\033[1;32m'; reset=$'\033[0m'
  printf '%s── Source (%s) ──%s\n' "$cyan" "$slang" "$reset"
  printf '%s\n\n' "$src"
  printf '%s── Translation (%s) ──%s\n' "$green" "$tlang" "$reset"
  printf '%s\n' "$dst"
}

# format_error <message>
format_error() {
  local red bold reset
  red=$'\033[1;31m'; bold=$'\033[1m'; reset=$'\033[0m'
  printf '%s── Translation error ──%s\n\n' "$red" "$reset"
  printf '%s\n\n' "$1"
  printf '%sHint:%s check the backends (translate-shell / curl / jq), your\n' "$bold" "$reset"
  printf '      network connection, and the @translate_engines setting.\n'
}
