#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
}

teardown() {
  teardown_sandbox
}

@test "shows a loading spinner before the result" {
  export STUB_TMUX_translate_engines=google
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Translating"* ]]
  [[ "$output" == *"⠋"* ]]            # at least one spinner frame
}

@test "translates via google and renders the result" {
  export STUB_TMUX_translate_engines=google
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
  [[ "$output" == *"Translation ("* ]]
}

@test "result is cached and served when the backend later fails" {
  export STUB_TMUX_translate_engines=google
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [ -n "$(ls -A "$XDG_CACHE_HOME/tmux-translate" 2>/dev/null)" ]

  export STUB_CURL_EXIT=1
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
}

@test "falls back to the next engine when the first fails" {
  export STUB_TMUX_translate_engines="trans google"
  export STUB_TRANS_EXIT=1
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Hello, world"* ]]
}

@test "reverses target language when the source already equals the target" {
  export STUB_TMUX_translate_engines=google
  export STUB_TMUX_translate_target_lang=ja
  export STUB_TMUX_translate_target_lang_alt=en
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"   # detected lang = ja
  run_render "こんにちは世界"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Translation (en)"* ]]
}

@test "renders an error when all engines fail" {
  export STUB_TMUX_translate_engines="trans google"
  export STUB_TRANS_EXIT=1
  export STUB_CURL_EXIT=1
  run_render "Hello, world"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Translation error"* ]]
}
