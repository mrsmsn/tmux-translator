# tmux-translator tasks.
# Lint and tests run inside a podman container so nothing is installed on the
# host. The repo is mounted read-only-ish at /work (writes happen in the
# container's own tmpfs sandbox under $TMPDIR).

image := "tmux-translator-ci"
run := "podman run --rm -v " + justfile_directory() + ":/work:Z " + image

default: check

# Build the CI container image.
build:
    podman build -t {{image}} -f Containerfile .

# Run shellcheck + bats inside the container.
check: build
    {{run}} bash ci/run-checks.sh

# Static analysis only.
lint: build
    {{run}} shellcheck translate.tmux scripts/translate.sh scripts/render.sh scripts/helpers.sh scripts/engines/*.sh tests/stubs/tmux tests/stubs/trans tests/stubs/curl ci/run-checks.sh

# Tests only.
test: build
    {{run}} bats tests

# Open a shell in the toolchain container for debugging.
shell: build
    podman run --rm -it -v {{justfile_directory()}}:/work:Z {{image}} bash
