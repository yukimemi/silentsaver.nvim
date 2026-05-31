# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## コンセプト

- **denops 廃止・pure Lua / Neovim 専用**: [`silentsaver.vim`](https://github.com/yukimemi/silentsaver.vim) (denops/Deno) の後継。編集中のバッファを event 駆動でバックグラウンド保存し、タイムスタンプ付きの版履歴を貯める。閲覧 (quickfix / `vim.ui.select`) と diff も提供。
- **保存をブロックしない**: ディスク I/O は全て `vim.uv` で非同期。`BufWritePre` / `CursorHold` で走るが、保存にレイテンシを足さない (denops の別プロセス非同期と同じ狙いを in-process で)。
- **設定はテーブル一本**: `g:silentsaver_*` グローバルは全廃。`require("silentsaver").setup({...})` のみ。`config.lua` に `M.defaults` + `vim.tbl_deep_extend` + LuaCATS。
- **Convention over Configuration**: `plugin/silentsaver.lua` が `:SilentSaver*` を eager 登録するので `setup()` 無しでもコマンドは効く。自動バックアップ (autocmd) だけ `setup()` 起点。
- **Notify ゲート契約**: background のログ (backup 完了 / 失敗) は全て `lua/silentsaver/log.lua` の `M.at/info/warn` 経由。`notify = false` で真に黙る。ユーザ起点コマンドの即時フィードバックだけ `log.echo`。

## Git ワークフロー

- **main に直接 push しない。** 必ずフィーチャーブランチ + Pull Request。
- ブランチ名は変更内容を端的に。**PR タイトル・本文・コミットメッセージは英語** (Conventional Commits)。
- 全 PR で **Gemini Code Assist** と **CodeRabbit** がレビュー。両 bot の指摘に対処 (fix push → `@gemini-code-assist` / `@coderabbitai` 付き reply) し、actionable が出なくなる + オーナー (@yukimemi) の明示承認まで merge しない。bot-authored PR (Renovate 等) はこの gate を適用しない。

## Development Commands

テストは **mini.test** (plenary.nvim は 2026-06-30 アーカイブのため不採用)。`scripts/run_tests.lua` が headless ランナーで失敗時 `cquit`。

```bash
# mini.nvim を用意 (CI は deps/mini.nvim に clone)
git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim
# または既存 clone を $MINI_NVIM で再利用

# 全 spec (CI と同じ per-file ループ)
set -e
status=0
for f in tests/silentsaver/test_*.lua; do
  echo "=== $f ==="
  nvim -u NONE -l scripts/run_tests.lua "$f" || status=$?
done
exit $status

# 単一 spec
nvim -u NONE -l scripts/run_tests.lua tests/silentsaver/test_backup.lua
```

- `nvim -u NONE -l` で user config を読まずに実行 (plenary の子 init.lua 罠を構造的に回避)。
- spec ファイル名は mini.test 既定の **`test_*.lua`**。

## アーキテクチャ

### ファイル構成

```text
plugin/silentsaver.lua      — :SilentSaver* を eager 登録
lua/silentsaver/
  init.lua                  — setup() + 便利 Lua API (backup/open/diff/enable/disable)
  config.lua                — defaults + tbl_deep_extend、LuaCATS ---@class silentsaver.Options
  log.lua                   — notify ゲート (at/info/warn) + ユーザ向け echo
  state.lua                 — enabled フラグ (memory)
  backup.lua                — コア: backup_path/original_path (可逆エンコード)、async I/O、dedup、retention、run()
  open.lua                  — open() 版一覧 (quickfix / ui.select)、diff() 元ファイルと diffsplit
  autocmd.lua               — augroup + events autocmd (setup で冪等)
  command.lua               — :SilentSaver{Backup,Open,Diff,Enable,Disable,Toggle}
  health.lua                — :checkhealth silentsaver
scripts/run_tests.lua       — headless mini.test ランナー
tests/silentsaver/test_*.lua
.github/workflows/ci.yml    — test (ubuntu/macos/windows × stable/nightly) + stylua lint
```

### バックアップのコア (`backup.lua`)

- **パスエンコード (`backup_path` / `original_path`)**: 保存先は `<dir>/<encode(origdir)>/<base>/<timestamp><ext>`。`encode_dir` は Windows のドライブコロン (`C:` → `C`) / Unix の root スラッシュを落とし、`decode_dir` が復元する。`original_path(backup_path(p)) == p` の **round-trip を必ずテスト**で守る (`test_backup.lua`)。per-file ディレクトリ (`dirname(backup_path)`) は timestamp に依らず安定。
- **timestamp**: `vim.uv.gettimeofday()` の秒と μ秒を**同一ソース**から取る。`os.date` (wall) と `hrtime` (monotonic) を混ぜると同一秒内で ms が前後しソートが壊れる — 過去にここでバグった。
- **async I/O**: `write_async` / `read_async` / `list_async` は `vim.uv.fs_*` のコールバック連鎖。libuv の fast context なので中で `vim.fn.*` を呼ばない (パス計算・mkdir は `run()` 冒頭のメインスレッドで済ませてから async に入る)。完了後の log / prune は `vim.schedule` で安全コンテキストに戻す。
- **dedup**: `dedupe = true` のとき、最新バックアップを読んで現バッファと一致なら書かない。
- **retention**: `max_per_file` / `max_age_days`。既定 0 = 無制限 (旧 denops と同じく無削除)。設定時のみ古い版を async unlink。**デフォルトで消さない** (不意のデータ損失回避)。

## 設計原則

- **保存を止めない.** backup の失敗は `log.warn` で握り、Neovim を止めない。autocmd は常に callback を消化。
- **Notify ゲート契約.** background の `vim.notify` は直書きせず `log.at` 系を経由。ユーザ起点のみ `log.echo`。
- **テスト先行.** パスや I/O の挙動変更は `tests/silentsaver/test_*.lua` に再現を書いてから。async write は「ファイル出現」ではなく **書き込み完了したコンテンツ**を `vim.wait` でポーリングする (fs_open は fs_write に先行するので出現だけ待つと空ファイルを読む)。
- **Windows 特性.** CI に `windows-latest` あり。`backup_path` のドライブコロン処理 / パス区切り / `stdpath("state")` の差異に注意。テストは `nvim -u NONE -l` で全 OS 共通。

## 移植元との差分 (denops 版からの設計変更)

- `g:silentsaver_*` グローバル → `setup()` テーブル一本。`debug` boolean → `log_level` + `notify` ゲート。
- 別プロセス async → in-process `vim.uv` async I/O。
- **retention (max_per_file / max_age_days) を新設** (旧版は無制限増殖)。
- 既定保存先を `~/.cache` → `stdpath("state")` に変更。
- backup パスのエンコード/デコードを round-trip テストで保証。
