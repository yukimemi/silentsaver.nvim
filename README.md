<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/yukimemi/silentsaver.nvim/main/assets/logo-dark.svg">
  <img src="https://raw.githubusercontent.com/yukimemi/silentsaver.nvim/main/assets/logo.svg" alt="silentsaver — silent, automatic file backups" width="520">
</picture>

<p><em>silent, automatic file backups.</em></p>

[![CI](https://github.com/yukimemi/silentsaver.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/yukimemi/silentsaver.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/yukimemi/silentsaver.nvim/blob/main/LICENSE)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white)](https://neovim.io)

</div>

Quietly snapshot your buffers in the background as you edit, keeping a
timestamped version history you can browse and diff. A pure-Lua, Neovim-only
rewrite of [silentsaver.vim](https://github.com/yukimemi/silentsaver.vim) (no
Deno / denops dependency); disk I/O is asynchronous, so saves are never
blocked.

## Requirements

- Neovim >= 0.10 (`vim.uv`)

## Install

With [rvpm](https://github.com/yukimemi/rvpm) (recommended):

```sh
rvpm add yukimemi/silentsaver.nvim --on-event BufReadPre,BufNewFile --on-cmd '/^SilentSaver.*$/'
```

Or in `config.toml`:

```toml
[[plugins]]
url = "https://github.com/yukimemi/silentsaver.nvim"
on_event = ["BufReadPre", "BufNewFile"]
on_cmd = ["/^SilentSaver.*$/"]
opts = {}
```

> Here `setup()` is **required**: the commands come up either way, but nothing
> is switched automatically until `require("silentsaver").setup(...)` installs the
> autocmds. **rvpm >= 3.45.0 handles it for you** — put `opts = {}` (or your
> options) in the `[[plugins]]` entry and rvpm calls
> `require("silentsaver").setup(<opts>)` right before the plugin's `after.lua`
> (same convention as lazy.nvim's `opts`). Use a hook
> (`rvpm edit yukimemi/silentsaver.nvim --after`) only when the options need a
> Lua function, which TOML cannot express.

Or with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yukimemi/silentsaver.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {},
}
```

`opts` is passed straight to `require("silentsaver").setup()`.

## Configuration

Defaults:

```lua
require("silentsaver").setup({
  notify = false,                          -- vim.notify on backup (gated by log_level)
  log_level = "warn",                      -- "trace"|"debug"|"info"|"warn"|"error"
  enabled = true,                          -- whether automatic backups start on
  dir = vim.fn.stdpath("state") .. "/silentsaver",
  events = { "BufWritePre", "CursorHold" },
  ignore_filetypes = { "log" },
  dedupe = true,                           -- skip when identical to the latest backup
  use_ui_select = false,                   -- :SilentSaverOpen via vim.ui.select vs quickfix
  diff_vertical = false,                   -- :SilentSaverDiff in a vertical split
  retention = {
    max_per_file = 0,                      -- keep at most N newest per file (0 = unlimited)
    max_age_days = 0,                      -- drop backups older than N days (0 = unlimited)
  },
})
```

Backups are written under:

```
<dir>/<original-path>/<filename>/<yyyymmdd_HHMMSSmmm><ext>
```

so every file gets its own directory of timestamped versions.

## Commands

| Command | Action |
| --- | --- |
| `:SilentSaverOpen` | Browse the backups of the current file (quickfix or `vim.ui.select`) |
| `:SilentSaverDiff` | Diff a backup (the current buffer) against its original file |
| `:SilentSaverBackup` | Back up the current buffer now |
| `:SilentSaverEnable` / `:SilentSaverDisable` / `:SilentSaverToggle` | Control automatic backups |

The commands work without calling `setup()`; only the automatic backup autocmd
needs `setup()`.

## Lua API

```lua
local ss = require("silentsaver")
ss.backup()   -- == :SilentSaverBackup
ss.open()     -- == :SilentSaverOpen
ss.diff()     -- == :SilentSaverDiff
ss.enable()
ss.disable()
```

## Health

```vim
:checkhealth silentsaver
```

## License

MIT
