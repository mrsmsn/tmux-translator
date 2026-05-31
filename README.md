# tmux-translator

**English** | [日本語](README.ja.md)

Translate the text you select in tmux **copy-mode** and read the result in a
floating popup — without leaving your terminal. Select an error log or a
paragraph of docs, press one key, and the original + translation appear in a
scrollable `tmux popup`.

```
┌──────────────────────────────────────────┐
│ ── Source (en) ──                          │
│ The connection was refused by the server. │
│                                            │
│ ── Translation (ja) ──                     │
│ 接続はサーバーによって拒否されました。       │
└──────────────────────────────────────────┘
```

- **Keyless by default** — uses [translate-shell] (`trans`) and falls back to
  Google's free endpoint via `curl`/`jq`. No API key required.
- **Pluggable engines** with fallback ordering (`@translate_engines`).
- **Auto language reversal** — selecting Japanese while translating *to*
  Japanese flips the target to English automatically.
- **Caching** so re-translating the same text is instant and offline-friendly.
- **Optional clipboard copy** of the translation.
- **Loading state** — the popup opens immediately with a "Translating…"
  indicator while the backend request is in flight.

## Requirements

- **tmux >= 3.2** (needs `display-popup`)
- **bash** (the scripts run under their own `#!/usr/bin/env bash`; your login
  shell — bash/zsh/fish — does not matter)
- At least one engine's dependencies:
  - `trans` engine → [translate-shell]
  - `google` engine → `curl` + `jq`
- Optional: a clipboard tool (`pbcopy` / `wl-copy` / `xclip` / `xsel`) for
  `@translate_clipboard on`

### Installing dependencies

```sh
# macOS (Homebrew)
brew install translate-shell jq

# Debian / Ubuntu
sudo apt install translate-shell jq

# Fedora
sudo dnf install translate-shell jq

# Arch
sudo pacman -S translate-shell jq
```

> Your interactive shell does not affect the plugin. If you keep the optional
> standalone scripts on your `PATH`, add `~/.local/bin` the usual way:
> bash/zsh → `export PATH="$HOME/.local/bin:$PATH"` in your rc file;
> fish → `fish_add_path ~/.local/bin`.

## Installation

### With [TPM] (recommended)

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'mrsmsn/tmux-translator'
```

Then press `prefix + I` to install. Make sure `mode-keys` is `vi`:

```tmux
setw -g mode-keys vi
```

### Manual

```sh
git clone https://github.com/mrsmsn/tmux-translator ~/.tmux/plugins/tmux-translator
```

Add to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-translator/translate.tmux
```

Reload tmux:

```sh
tmux source-file ~/.tmux.conf
```

## Usage

1. Enter copy-mode: `prefix + [`
2. Start a selection with `v` and move to select the text.
3. Press **`T`** (configurable). The selection is captured, copy-mode exits,
   and the translation popup opens.
4. Scroll with `j`/`k` (it's `less -R`); press `q` to close and return to work.

The background pane is never overwritten.

## Configuration

All configuration is done with tmux user options in `~/.tmux.conf` (set them
**before** the plugin's `run-shell`/TPM line).

| Option | Default | Description |
| --- | --- | --- |
| `@translate_key` | `T` | Key in `copy-mode-vi` that triggers translation |
| `@translate_engines` | `trans google` | Engine fallback order (space-separated) |
| `@translate_source_lang` | `auto` | Source language (`auto` enables detection) |
| `@translate_target_lang` | `ja` | Target language |
| `@translate_target_lang_alt` | `en` | Target used when the source already equals `@translate_target_lang` |
| `@translate_cache` | `on` | Cache translations under `$XDG_CACHE_HOME/tmux-translate` |
| `@translate_clipboard` | `off` | Copy the translation to the system clipboard |
| `@translate_pager` | `less -R` | Pager command used to display the result |
| `@translate_popup_width` | `80%` | Maximum popup width (the popup shrinks to fit the content) |
| `@translate_popup_height` | `80%` | Maximum popup height (the popup shrinks to fit the content) |

Example:

```tmux
setw -g mode-keys vi
set -g @translate_key 'T'
set -g @translate_engines 'trans google'
set -g @translate_target_lang 'ja'
set -g @translate_clipboard 'on'
set -g @plugin 'mrsmsn/tmux-translator'
```

## How it works

`copy-pipe-and-cancel` pipes the selection into `scripts/translate.sh` (the
entry stage), which sizes a popup from the selection and opens
`tmux display-popup` running `scripts/render.sh` (the popup stage). Inside the
popup, `render.sh`:

1. shows a "Translating…" loading state immediately,
2. reads the configured `@options`,
3. checks the cache (keyed by text + engines + languages),
4. detects the source language and reverses the target if needed,
5. tries each engine in order until one succeeds,
6. formats the original + translation and shows them in the pager
   (`@translate_pager`, default `less -R`).

The popup is sized to the selection (up to `@translate_popup_width` /
`@translate_popup_height`) so small selections get a small popup.

### Adding an engine

Each engine is a file in `scripts/engines/<name>.sh` that defines
`translate_<name> <text> <source> <target>` (prints the translation, exits
non-zero on failure) and optionally `detect_<name> <text>`. Add its name to
`@translate_engines`. This is the extension point for future API-key backends
(DeepL, Google Cloud, …).

## Troubleshooting

- **"Translation error" popup** — no engine succeeded. Check that `trans` or
  `curl`+`jq` are installed and that you have network access. Try a single
  engine, e.g. `set -g @translate_engines 'google'`.
- **No popup appears** — confirm `tmux -V` is `>= 3.2` and `mode-keys` is `vi`.
- **Wrong key** — another binding may own `T`; change `@translate_key`.

## Development

Lint and tests run in a container (via [podman]) so you never install
`bats`/`shellcheck` on your host:

```sh
just check   # build image + shellcheck + bats
just lint    # shellcheck only
just test    # bats only
just shell   # debug shell in the toolchain container
```

CI runs the exact same `ci/run-checks.sh` inside the same image.

## License

[MIT](LICENSE)

[translate-shell]: https://github.com/soimort/translate-shell
[TPM]: https://github.com/tmux-plugins/tpm
[podman]: https://podman.io/
