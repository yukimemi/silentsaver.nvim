local M = {}

---@class silentsaver.Retention
---@field max_per_file integer  Keep at most N newest backups per file. 0 = unlimited.
---@field max_age_days integer  Delete backups older than N days. 0 = unlimited.

---@class silentsaver.Options
---@field notify boolean             Emit `vim.notify` on backup (gated by `log_level`). Default false.
---@field log_level "trace"|"debug"|"info"|"warn"|"error"  Minimum severity surfaced when `notify = true`. Default "warn".
---@field enabled boolean            Whether automatic backups start enabled. Default true.
---@field dir string                 Root directory for backups.
---@field events string[]            Autocmd events that trigger a backup. Default {"BufWritePre","CursorHold"}.
---@field ignore_filetypes string[]  Filetypes never backed up.
---@field dedupe boolean             Skip a backup when the buffer is identical to the latest one. Default true.
---@field use_ui_select boolean      `:SilentSaverOpen` uses `vim.ui.select` instead of the quickfix list. Default false.
---@field diff_vertical boolean      `:SilentSaverDiff` opens a vertical split. Default false.
---@field retention silentsaver.Retention  Backup pruning policy. Defaults to unlimited.

M.defaults = {
  notify = false,
  log_level = "warn",
  enabled = true,
  dir = vim.fn.stdpath("state") .. "/silentsaver",
  events = { "BufWritePre", "CursorHold" },
  ignore_filetypes = { "log" },
  dedupe = true,
  use_ui_select = false,
  diff_vertical = false,
  retention = {
    max_per_file = 0,
    max_age_days = 0,
  },
}

M.options = vim.deepcopy(M.defaults)

---@param opts? silentsaver.Options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
