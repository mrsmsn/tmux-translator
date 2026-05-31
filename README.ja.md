# tmux-translator

[English](README.md) | **日本語**

tmux の **コピーモード**で選択したテキストを翻訳し、ターミナルを離れることなく
フローティングポップアップで結果を読めるツールです。エラーログやドキュメントの
一節を選択してキーを 1 つ押すだけで、原文と訳文がスクロール可能な
`tmux popup` に表示されます。

```
┌──────────────────────────────────────────┐
│ ── Source (en) ──                          │
│ The connection was refused by the server. │
│                                            │
│ ── Translation (ja) ──                     │
│ 接続はサーバーによって拒否されました。       │
└──────────────────────────────────────────┘
```

- **既定でキーレス** — [translate-shell]（`trans`）を使い、未導入時は `curl`/`jq`
  経由で Google の無料エンドポイントにフォールバック。API キー不要。
- **プラガブルなエンジン**とフォールバック順（`@translate_engines`）。
- **言語の自動反転** — 日本語を選択して日本語へ翻訳しようとすると、自動的に
  翻訳先を英語に切り替えます。
- **キャッシュ**により、同じ文の再翻訳は即時かつオフラインでも動作。
- **クリップボードへのコピー**（任意）。
- **ローディング表示** — バックエンドへのリクエスト中、ポップアップが即座に開き
  「Translating…」と表示されます。

## 動作要件

- **tmux >= 3.2**（`display-popup` が必要）
- **bash**（スクリプトは独自の `#!/usr/bin/env bash` で動作するため、ログイン
  シェルが bash/zsh/fish のいずれでも問題ありません）
- いずれかのエンジンの依存:
  - `trans` エンジン → [translate-shell]
  - `google` エンジン → `curl` + `jq`
- 任意: クリップボードツール（`pbcopy` / `wl-copy` / `xclip` / `xsel`）。
  `@translate_clipboard on` で使用。

### 依存ツールのインストール

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

> 対話シェルはプラグインの動作に影響しません。任意でスタンドアロンスクリプトを
> `PATH` に置く場合は、通常どおり `~/.local/bin` を追加してください:
> bash/zsh → rc ファイルに `export PATH="$HOME/.local/bin:$PATH"`、
> fish → `fish_add_path ~/.local/bin`。

## インストール

### [TPM] を使う場合（推奨）

`~/.tmux.conf` に追記:

```tmux
set -g @plugin 'mrsmsn/tmux-translator'
```

`prefix + I` を押してインストールします。`mode-keys` が `vi` であることを確認してください:

```tmux
setw -g mode-keys vi
```

### 手動

```sh
git clone https://github.com/mrsmsn/tmux-translator ~/.tmux/plugins/tmux-translator
```

`~/.tmux.conf` に追記:

```tmux
run-shell ~/.tmux/plugins/tmux-translator/translate.tmux
```

tmux を再読み込み:

```sh
tmux source-file ~/.tmux.conf
```

## 使い方

1. コピーモードに入る: `prefix + [`
2. `v` で選択を開始し、カーソルを動かしてテキストを選択する。
3. **`T`**（変更可能）を押す。選択範囲がキャプチャされてコピーモードが終了し、
   翻訳ポップアップが開きます。
4. `j`/`k` でスクロール（`less -R`）、`q` で閉じて作業に復帰します。

背面のペインが上書きされることはありません。

## 設定

設定はすべて `~/.tmux.conf` の tmux ユーザーオプションで行います（プラグインの
`run-shell`/TPM 行**より前**に記述してください）。

| オプション | 既定値 | 説明 |
| --- | --- | --- |
| `@translate_key` | `T` | `copy-mode-vi` で翻訳を起動するキー |
| `@translate_engines` | `trans google` | エンジンのフォールバック順（空白区切り） |
| `@translate_source_lang` | `auto` | 変換元言語（`auto` で自動検出） |
| `@translate_target_lang` | `ja` | 変換先言語 |
| `@translate_target_lang_alt` | `en` | 原文が `@translate_target_lang` と同じ場合の代替変換先 |
| `@translate_cache` | `on` | `$XDG_CACHE_HOME/tmux-translate` に翻訳をキャッシュ |
| `@translate_clipboard` | `off` | 翻訳結果をシステムクリップボードへコピー |
| `@translate_pager` | `less -R` | 結果表示に使うページャコマンド |
| `@translate_popup_width` | `80%` | ポップアップ幅の上限（内容に合わせて縮小） |
| `@translate_popup_height` | `80%` | ポップアップ高さの上限（内容に合わせて縮小） |

例:

```tmux
setw -g mode-keys vi
set -g @translate_key 'T'
set -g @translate_engines 'trans google'
set -g @translate_target_lang 'ja'
set -g @translate_clipboard 'on'
set -g @plugin 'mrsmsn/tmux-translator'
```

## 仕組み

`copy-pipe-and-cancel` が選択範囲を `scripts/translate.sh`（エントリ段）にパイプし、
エントリ段は選択範囲からポップアップのサイズを見積もり、`scripts/render.sh`（ポップ
アップ段）を実行する `tmux display-popup` を開きます。ポップアップ内で `render.sh` は
次を行います:

1. 「Translating…」のローディング状態を即座に表示する、
2. 設定された `@options` を読み込む、
3. キャッシュを照合する（鍵 = 原文 + エンジン + 言語）、
4. 変換元言語を検出し、必要なら翻訳先を反転する、
5. 各エンジンを順に試し、最初に成功したものを採用する、
6. 原文と訳文を整形し、ページャ（`@translate_pager`、既定 `less -R`）で表示する。

ポップアップは選択範囲に合わせてサイズ調整され（長い行が折り返した際に必要となる
高さも考慮。`@translate_popup_width` / `@translate_popup_height` を上限とする）、
選択範囲が少ないときは小さく表示されます。

### エンジンの追加

各エンジンは `scripts/engines/<name>.sh` のファイルで、`translate_<name> <text>
<source> <target>`（訳文を stdout に出力、失敗時は非ゼロで終了）を定義し、任意で
`detect_<name> <text>` を定義します。その名前を `@translate_engines` に追加します。
これが将来の API キー型バックエンド（DeepL、Google Cloud など）の拡張点です。

## トラブルシューティング

- **"Translation error" ポップアップ** — どのエンジンも成功しませんでした。`trans`
  または `curl`+`jq` がインストールされているか、ネットワークに接続できているかを
  確認してください。`set -g @translate_engines 'google'` のように単一エンジンに
  絞ると切り分けやすくなります。
- **ポップアップが出ない** — `tmux -V` が `>= 3.2` か、`mode-keys` が `vi` かを確認。
- **キーが効かない** — 他のバインドが `T` を使っている可能性があります。
  `@translate_key` を変更してください。

## 開発

lint とテストは（[podman] 経由で）コンテナ内で実行するため、`bats`/`shellcheck` を
ホストに入れる必要はありません:

```sh
just check   # イメージのビルド + shellcheck + bats
just lint    # shellcheck のみ
just test    # bats のみ
just shell   # ツールチェインコンテナのデバッグシェル
```

CI も同じイメージ内でまったく同じ `ci/run-checks.sh` を実行します。

## ライセンス

[MIT](LICENSE)

[translate-shell]: https://github.com/soimort/translate-shell
[TPM]: https://github.com/tmux-plugins/tpm
[podman]: https://podman.io/
