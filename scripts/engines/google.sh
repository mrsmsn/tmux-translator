#!/usr/bin/env bash
# Google free-endpoint engine (keyless). Requires curl + jq.
# Contract: translate_google <text> <source> <target> -> translated text.
# Optional: detect_google <text> -> detected ISO language code.

# _google_fetch <source> <target> <text> -> raw JSON on stdout.
_google_fetch() {
  curl -fsS --max-time 10 -G 'https://translate.googleapis.com/translate_a/single' \
    --data-urlencode 'client=gtx' \
    --data-urlencode "sl=$1" \
    --data-urlencode "tl=$2" \
    --data-urlencode 'dt=t' \
    --data-urlencode "q=$3"
}

translate_google() {
  local text="$1" source="$2" target="$3" json out
  if ! command -v curl >/dev/null 2>&1; then
    echo "google: curl not found" >&2; return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "google: jq not found" >&2; return 1
  fi
  if ! json="$(_google_fetch "$source" "$target" "$text")"; then
    echo "google: network error or rate limit" >&2; return 1
  fi
  out="$(printf '%s' "$json" | jq -r '[.[0][]? | .[0]] | join("")' 2>/dev/null)"
  if [ -z "$out" ]; then
    echo "google: failed to parse response" >&2; return 1
  fi
  printf '%s' "$out"
}

detect_google() {
  local text="$1" json
  command -v curl >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  json="$(_google_fetch auto en "$text")" || return 1
  printf '%s' "$json" | jq -r '.[2] // empty' 2>/dev/null
}
