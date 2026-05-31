#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
}

teardown() {
  teardown_sandbox
}

@test "empty selection is a no-op (no popup)" {
  run_translate "   "
  [ "$status" -eq 0 ]
  [ ! -s "$STUB_TMUX_LOG" ]
}

@test "translates via google and opens a popup" {
  export STUB_TMUX_translate_engines=google
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  grep -q 'display-popup' "$STUB_TMUX_LOG"
  popup_file_content | grep -q "Hello, world"
}

@test "result is cached and served when the backend later fails" {
  export STUB_TMUX_translate_engines=google
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  # A cache file must now exist.
  [ -n "$(ls -A "$XDG_CACHE_HOME/tmux-translate" 2>/dev/null)" ]

  # Second run with the backend broken still succeeds from cache.
  : > "$STUB_TMUX_LOG"
  export STUB_CURL_EXIT=1
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  popup_file_content | grep -q "Hello, world"
}

@test "falls back to the next engine when the first fails" {
  export STUB_TMUX_translate_engines="trans google"
  export STUB_TRANS_EXIT=1
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  popup_file_content | grep -q "Hello, world"
}

@test "reverses target language when the source already equals the target" {
  export STUB_TMUX_translate_engines=google
  export STUB_TMUX_translate_target_lang=ja
  export STUB_TMUX_translate_target_lang_alt=en
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"   # detected lang = ja
  run_translate "こんにちは世界"
  [ "$status" -eq 0 ]
  popup_file_content | grep -q "翻訳 (en)"
}

@test "shows an error popup when all engines fail" {
  export STUB_TMUX_translate_engines="trans google"
  export STUB_TRANS_EXIT=1
  export STUB_CURL_EXIT=1
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  popup_file_content | grep -q "翻訳エラー"
}
