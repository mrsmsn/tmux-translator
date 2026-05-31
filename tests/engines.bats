#!/usr/bin/env bats

setup() {
  load test_helper
  setup_sandbox
  source "$SCRIPTS/engines/google.sh"
  source "$SCRIPTS/engines/trans.sh"
}

teardown() {
  teardown_sandbox
}

@test "translate_google extracts the joined translation" {
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run translate_google "Hello, world" en ja
  [ "$status" -eq 0 ]
  [ "$output" = "Hello, world" ]
}

@test "detect_google returns the detected language code" {
  export STUB_CURL_FIXTURE="$FIXTURES/google.json"
  run detect_google "こんにちは"
  [ "$status" -eq 0 ]
  [ "$output" = "ja" ]
}

@test "translate_google fails on a curl/network error" {
  export STUB_CURL_EXIT=7
  run translate_google "Hello" en ja
  [ "$status" -ne 0 ]
  [[ "$output" == *"network"* ]]
}

@test "translate_trans returns the brief translation" {
  export STUB_TRANS_OUT="やあ世界"
  run translate_trans "Hello world" en ja
  [ "$status" -eq 0 ]
  [ "$output" = "やあ世界" ]
}

@test "translate_trans fails when trans exits non-zero" {
  export STUB_TRANS_EXIT=1
  run translate_trans "Hello" en ja
  [ "$status" -ne 0 ]
}
