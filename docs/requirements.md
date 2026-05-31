# ターミナル選択範囲の即時翻訳ツール (Tmux Plugin) 実装要件

## 1. 概要

Tmux のコピーモード（vi バインド）で選択したターミナル上のテキスト（エラーログ、
ドキュメントなど）を、指定したバックエンド（Google 翻訳など）を用いて翻訳し、
ポップアップ表示するツールを実装する。**OSS として公開する**ことを前提とする。

## 2. 機能要件 (UX フロー)

1. **トリガー:** ユーザーが Tmux のコピーモードに入り（`Prefix + [`）、`v` 等でテキストをビジュアル選択する。
2. **実行:** 選択状態で特定のキー（既定: `T`）を押下する。
3. **キャプチャ:** 選択されたテキスト領域が取得され、コピーモードが終了する。
4. **翻訳処理:** バックグラウンドで翻訳エンジンにキャプチャしたテキストを送信する。
5. **表示:** Tmux のフローティングウィンドウ（`tmux popup`）が画面中央に展開され、「原文」と「翻訳結果」が表示される。
6. **閲覧と復帰:** ポップアップ内はページャー（`less -R`）でスクロール可能。`q` を押すとポップアップが閉じ、元の作業に復帰する。

## 3. 設定要件 (Config)

設定は **tmux ユーザーオプション（`@options`）** で行う。`~/.tmux.conf` に
`@translate_*` を記述し、未設定時は既定値を用いる。

| オプション | 既定値 | 説明 |
| --- | --- | --- |
| `@translate_key` | `T` | `copy-mode-vi` で翻訳を起動するキー |
| `@translate_engines` | `trans google` | エンジンのフォールバック順（空白区切り） |
| `@translate_source_lang` | `auto` | 変換元言語（`auto` で自動検出） |
| `@translate_target_lang` | `ja` | 変換先言語 |
| `@translate_target_lang_alt` | `en` | 原文が `@translate_target_lang` と同じ場合の代替変換先 |
| `@translate_cache` | `on` | 翻訳キャッシュの有効化 |
| `@translate_clipboard` | `off` | 翻訳結果をシステムクリップボードへコピー |
| `@translate_popup_width` | `80%` | ポップアップ幅の上限（内容量に合わせて縮小） |
| `@translate_popup_height` | `80%` | ポップアップ高さの上限（内容量に合わせて縮小） |

## 4. 非機能要件

* **依存関係:** 翻訳には `translate-shell`（`trans`）、または `curl` + `jq` を用いる。クリップボード連携は `pbcopy` / `wl-copy` / `xclip` / `xsel` のいずれかを任意で利用する。
* **tmux バージョン:** `display-popup` を使用するため **tmux >= 3.2** を要求する。下回る場合はローダで警告する。
* **エラーハンドリング:** ネットワークエラーや API 制限超過が発生した場合、ポップアップ内で原因が分かるエラーメッセージを表示する。
* **ターミナル環境の維持:** ポップアップ表示によって、背面の作業中のペインやバッファのテキストが破壊・上書きされないこと。
* **言語/文言:** OSS であることを踏まえ、**ツールが出力する文言（エラー・ポップアップのヘッダ・警告）は英語**とする。翻訳結果の中身はエンジン出力のまま。

## 5. システムアーキテクチャ・構成要素

### A. TPM エントリ (`translate.tmux`)

* `@options` を読み取り、`copy-mode-vi` の設定キーに `copy-pipe-and-cancel` で選択範囲を `scripts/translate.sh` へ渡すバインドを定義する。
* `mode-keys vi` を前提とする。
* tmux のバージョンを判定し、3.2 未満なら `display-message` で警告する。

### B. 本体スクリプト (`scripts/translate.sh`)

* 標準入力 (stdin) からテキストを受け取る（空入力は no-op）。
* `@options` を読み込み、キャッシュ照合 → 言語検出・反転 → エンジン順次試行 → 整形 → `tmux display-popup` 表示を行う。
* 翻訳結果と原文を ANSI 色付きで整形し、`less -R` でスクロール表示する。
* ポップアップは内容量（行数・最大表示幅。ANSI 除去・CJK は 2 桁換算）に合わせてサイズ調整し、`@translate_popup_width`/`_height` を上限、読みやすい最小値を下限とする。選択範囲が少ないときは小さく表示する。

### C. ヘルパ (`scripts/helpers.sh`)

* `get_tmux_option` / バージョン比較 / キャッシュ（鍵生成・get・set）/ クリップボードコマンド検出 / 出力整形。

### D. エンジン抽象層 (`scripts/engines/<name>.sh`)

* 各エンジンは `translate_<name> <text> <source> <target>`（成功時に訳文を stdout、失敗時に exit != 0）を定義する。任意で `detect_<name> <text>` を定義する。
* v1 同梱: `trans`（translate-shell・既定）、`google`（curl/jq による Google 無料エンドポイント・フォールバック）。
* これが将来の API キー型バックエンド（DeepL / Google Cloud 等）の拡張点となる。

## 6. 技術要件・設計方針

* **配布:** TPM 互換プラグイン（`set -g @plugin 'mrsmsn/tmux-translator'`）を主軸とし、手動インストール手順も併記する。
* **エンジン戦略:** v1 は **キーレスのみ**。既定は `translate-shell`、未導入時は `curl`/`jq` の Google 無料エンドポイントにフォールバックする。エンジン抽象層により将来 API キー型を追加可能とする。ローカル LLM は対象外。
* **追加機能（v1 スコープ）:**
  * 翻訳キャッシュ（同一原文の再翻訳を回避、オフライン再利用。`$XDG_CACHE_HOME/tmux-translate`）。
  * 言語自動検出と target 反転（`source=auto` かつ検出言語が `target` と一致する場合に `*_alt` へ反転）。
  * 翻訳結果のクリップボードコピー（`@translate_clipboard on` 時）。
  * **対象外:** 翻訳履歴ログ。
* **実装シェル:** `bash` 固定（`#!/usr/bin/env bash`）。ユーザーの対話シェル（bash/zsh/fish）には非依存。README に各シェルの依存 PATH 手順を記載する。
* **ハッシュの可搬性:** キャッシュ鍵は `shasum`／`sha1sum`／`cksum` のいずれか利用可能なものを用いる（macOS/Linux 両対応）。
* **ライセンス:** MIT。
* **品質保証 (TDD/CI):**
  * `bats-core` でテスト（tmux/trans/curl はスタブでモック）、`shellcheck` で静的検査。
  * これらは **podman コンテナ**（`Containerfile`）で実行し、ローカル環境を汚さない。
  * チェック実体は `ci/run-checks.sh` に集約し、`justfile`（host から podman 起動）と GitHub Actions で共有する。

## 7. 成果物

* `~/.tmux.conf` への追加スニペット（TPM / 手動）。→ `README.md`
* `translate.tmux`（TPM エントリ）。
* `scripts/translate.sh` 本体、`scripts/helpers.sh`、`scripts/engines/{trans,google}.sh`。
* `README.md`（概要・依存インストール（macOS/Linux）・TPM/手動導入・`@options` 一覧・使い方・トラブルシュート）。
* `tests/`（bats テスト・スタブ・fixture）、`Containerfile`、`justfile`、`.github/workflows/ci.yml`、`LICENSE`（MIT）。
