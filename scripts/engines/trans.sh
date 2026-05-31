#!/usr/bin/env bash
# translate-shell engine (keyless). Requires the `trans` command.
# Contract: translate_trans <text> <source> <target> -> translated text on
# stdout (exit 0) or a diagnostic on stderr (exit != 0).

translate_trans() {
  local text="$1" source="$2" target="$3" out
  if ! command -v trans >/dev/null 2>&1; then
    echo "trans: translate-shell (trans) not found" >&2
    return 1
  fi
  if ! out="$(trans -b -no-ansi -s "$source" -t "$target" -- "$text" 2>/dev/null)"; then
    echo "trans: translation request failed (possible network or rate-limit issue)" >&2
    return 1
  fi
  if [ -z "$out" ]; then
    echo "trans: empty response" >&2
    return 1
  fi
  printf '%s' "$out"
}
