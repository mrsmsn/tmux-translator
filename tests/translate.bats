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

@test "opens a popup that runs the render stage" {
  export STUB_CLIENT_WIDTH=200
  export STUB_CLIENT_HEIGHT=50
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  grep -q 'display-popup' "$STUB_TMUX_LOG"
  grep -q 'render.sh' "$STUB_TMUX_LOG"
}

@test "popup shrinks to fit a small selection" {
  export STUB_CLIENT_WIDTH=200
  export STUB_CLIENT_HEIGHT=50
  run_translate "Hello, world"
  [ "$status" -eq 0 ]
  # Tiny content stays far below the 80% cap (160x40).
  [ "$(popup_arg -w)" -lt 40 ]
  [ "$(popup_arg -h)" -lt 12 ]
}

@test "popup height accounts for line wrapping" {
  export STUB_TMUX_translate_popup_width=20%   # max width -> 40 cols
  export STUB_CLIENT_WIDTH=200
  export STUB_CLIENT_HEIGHT=100                 # tall enough not to clamp height
  run_translate "$(printf 'x%.0s' {1..100})"    # one 100-col line, wraps at ~38
  [ "$status" -eq 0 ]
  [ "$(popup_arg -w)" -eq 40 ]
  # 100 cols / 38 -> 3 visual rows, counted for source + translation + headers,
  # so the height is well above the no-wrap minimum (which would be ~8).
  [ "$(popup_arg -h)" -ge 10 ]
}

@test "popup is capped at the configured maximum" {
  export STUB_TMUX_translate_popup_width=10%
  export STUB_TMUX_translate_popup_height=10%
  export STUB_CLIENT_WIDTH=200    # 10% -> 20 cols
  export STUB_CLIENT_HEIGHT=50    # 10% -> 5 rows
  # A tall selection so the estimate exceeds the cap and must be clamped.
  run_translate "$(printf 'line\n%.0s' {1..20})"
  [ "$status" -eq 0 ]
  [ "$(popup_arg -w)" -eq 20 ]
  [ "$(popup_arg -h)" -eq 5 ]
}
