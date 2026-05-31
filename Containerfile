# CI toolchain for tmux-translator.
# Contains everything needed to lint and test the plugin so contributors never
# have to install bats/shellcheck on their host. The repo is mounted at /work.
FROM alpine:3.20

RUN apk add --no-cache \
      bash \
      bats \
      shellcheck \
      jq \
      grep \
      coreutils

WORKDIR /work

# Default: run the full check suite against the mounted repo.
CMD ["bash", "ci/run-checks.sh"]
