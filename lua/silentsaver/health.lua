local M = {}

local h = vim.health
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local info = h.info or h.report_info
local warn = h.warn or h.report_warn

function M.check()
  start("silentsaver")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10")
  else
    warn("Neovim 0.10+ recommended (vim.uv)")
  end

  local options = require("silentsaver.config").options
  local state = require("silentsaver.state")
  local dir = vim.fs.normalize(options.dir)

  if vim.fn.isdirectory(dir) == 1 then
    if vim.fn.filewritable(dir) == 2 then
      ok("backup dir writable: " .. dir)
    else
      warn("backup dir not writable: " .. dir)
    end
  else
    info("backup dir will be created on first backup: " .. dir)
  end

  info("enabled: " .. tostring(state.enabled))
  info(("events: %s"):format(table.concat(options.events, ", ")))
  info(("ignored filetypes: %d"):format(#(options.ignore_filetypes or {})))
  local r = options.retention or {}
  if (r.max_per_file or 0) > 0 or (r.max_age_days or 0) > 0 then
    info(("retention: max_per_file=%d, max_age_days=%d"):format(r.max_per_file or 0, r.max_age_days or 0))
  else
    info("retention: unlimited")
  end
end

return M
