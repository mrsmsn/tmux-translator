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

# Run the main translate script with the given text on stdin.
run_translate() {
  run bash -c 'printf "%s" "$1" | "$2"' _ "$1" "$SCRIPTS/translate.sh"
}

# Print the contents of the file handed to `less` inside display-popup.
popup_file_content() {
  local fname
  fname="$(grep -oE 'tmux-translate\.[A-Za-z0-9]+' "$STUB_TMUX_LOG" | head -1)"
  [ -n "$fname" ] || return 1
  cat -- "$TMPDIR/$fname"
}
