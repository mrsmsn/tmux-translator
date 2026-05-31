# Shared setup for bats tests. Source from each .bats file's setup().

setup_sandbox() {
  PROJECT_ROOT="$(cd -- "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPTS="$PROJECT_ROOT/scripts"
  STUBS="$BATS_TEST_DIRNAME/stubs"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"

  # Prepend stubs so tmux/trans/curl are mocked.
  PATH="$STUBS:$PATH"
  export PATH

  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX"
  export XDG_CACHE_HOME="$SANDBOX/.cache"
  export TMPDIR="$SANDBOX"
  export STUB_TMUX_LOG="$SANDBOX/tmux.log"
  : > "$STUB_TMUX_LOG"
}

teardown_sandbox() {
  [ -n "${SANDBOX:-}" ] && rm -rf -- "$SANDBOX"
}

# Run the entry stage with the given text on stdin.
run_translate() {
  run bash -c 'printf "%s" "$1" | "$2"' _ "$1" "$SCRIPTS/translate.sh"
}

# Run the popup (render) stage on the given text. Uses `cat` as the pager so
# the formatted result is captured on stdout instead of opening a real pager.
run_render() {
  local f
  f="$(mktemp "$SANDBOX/src.XXXXXX")"
  printf '%s' "$1" > "$f"
  export STUB_TMUX_translate_pager=cat
  run bash "$SCRIPTS/render.sh" "$f"
}

# Print the contents of the file handed to `less` inside display-popup.
popup_file_content() {
  local fname
  fname="$(grep -oE 'tmux-translate\.[A-Za-z0-9]+' "$STUB_TMUX_LOG" | head -1)"
  [ -n "$fname" ] || return 1
  cat -- "$TMPDIR/$fname"
}

# Print the value passed to a display-popup flag (e.g. -w or -h).
popup_arg() {
  awk -v flag="$1" '/^display-popup/ {
    for (i = 1; i < NF; i++) if ($i == flag) { print $(i + 1); exit }
  }' "$STUB_TMUX_LOG"
}
