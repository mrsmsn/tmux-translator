#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
  source "$SCRIPTS/helpers.sh"
}

teardown() {
  teardown_sandbox
}

@test "get_tmux_option returns default when option is unset" {
  run get_tmux_option @translate_target_lang ja
  [ "$status" -eq 0 ]
  [ "$output" = "ja" ]
}

@test "get_tmux_option returns the configured value" {
  export STUB_TMUX_translate_target_lang=fr
  run get_tmux_option @translate_target_lang ja
  [ "$output" = "fr" ]
}

@test "version_ge compares major.minor" {
  run version_ge "tmux 3.3a" 3.2
  [ "$status" -eq 0 ]
  run version_ge 3.2 3.2
  [ "$status" -eq 0 ]
  run version_ge 3.1 3.2
  [ "$status" -ne 0 ]
}

@test "cache_key is stable and input-sensitive" {
  k1="$(cache_key "hello" "google" en ja)"
  k2="$(cache_key "hello" "google" en ja)"
  k3="$(cache_key "world" "google" en ja)"
  [ -n "$k1" ]
  [ "$k1" = "$k2" ]
  [ "$k1" != "$k3" ]
}

@test "cache_set then cache_get round-trips; miss returns non-zero" {
  printf 'cached-body' | cache_set abc123
  run cache_get abc123
  [ "$status" -eq 0 ]
  [ "$output" = "cached-body" ]

  run cache_get does-not-exist
  [ "$status" -ne 0 ]
}

@test "clipboard_cmd picks pbcopy when available" {
  bin="$SANDBOX/bin"; mkdir -p "$bin"
  printf '#!/bin/sh\n' > "$bin/pbcopy"; chmod +x "$bin/pbcopy"
  PATH="$bin" run clipboard_cmd
  [ "$status" -eq 0 ]
  [ "$output" = "pbcopy" ]
}

@test "clipboard_cmd fails when no clipboard tool exists" {
  bin="$SANDBOX/emptybin"; mkdir -p "$bin"
  PATH="$bin" run clipboard_cmd
  [ "$status" -ne 0 ]
}

@test "format_result includes both languages" {
  run format_result "hello" "やあ" en ja
  [ "$status" -eq 0 ]
  [[ "$output" == *"Source (en)"* ]]
  [[ "$output" == *"Translation (ja)"* ]]
  [[ "$output" == *"やあ"* ]]
}

@test "text_dims counts rows and ASCII width" {
  printf 'abc\nde\n' > "$SANDBOX/f"
  run text_dims "$SANDBOX/f"
  [ "$output" = "2 3" ]
}

@test "text_dims counts CJK characters as double-width" {
  printf 'ややや\n' > "$SANDBOX/f"   # 3 chars x 2 cols
  run text_dims "$SANDBOX/f"
  [ "$output" = "1 6" ]
}

@test "text_dims ignores ANSI colour codes" {
  printf '\033[1;36mabc\033[0m\n' > "$SANDBOX/f"
  run text_dims "$SANDBOX/f"
  [ "$output" = "1 3" ]
}

@test "wrapped_rows counts visual rows after wrapping" {
  printf 'xxxxxxxxxx\n' > "$SANDBOX/f"     # 10 cols, wrap at 4 -> 3 rows
  [ "$(wrapped_rows "$SANDBOX/f" 4)" = "3" ]
}

@test "wrapped_rows sums lines and counts an empty line as one row" {
  printf 'xxxxxxxxxx\n\nyy\n' > "$SANDBOX/f"  # 3 + 1 + 1
  [ "$(wrapped_rows "$SANDBOX/f" 4)" = "5" ]
}

@test "clamp constrains to range; max wins when max<min" {
  [ "$(clamp 5 1 10)" = "5" ]
  [ "$(clamp 0 2 10)" = "2" ]
  [ "$(clamp 99 2 10)" = "10" ]
  [ "$(clamp 50 24 10)" = "10" ]
}

@test "resolve_size handles percentages and bare numbers" {
  [ "$(resolve_size 80% 100)" = "80" ]
  [ "$(resolve_size 50% 200)" = "100" ]
  [ "$(resolve_size 60 999)" = "60" ]
}
