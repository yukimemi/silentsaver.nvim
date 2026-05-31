local M = {}

---Configure silentsaver and start automatic backups.
---@param opts? silentsaver.Options
function M.setup(opts)
  local cfg = require("silentsaver.config")
  cfg.setup(opts)
  require("silentsaver.state").enabled = cfg.options.enabled
  require("silentsaver.command").register()
  require("silentsaver.autocmd").register()
end

-- Convenience Lua API mirroring the `:SilentSaver*` commands.

function M.backup()
  require("silentsaver.backup").run()
end

function M.open()
  require("silentsaver.open").open()
end

function M.diff()
  require("silentsaver.open").diff()
end

function M.enable()
  require("silentsaver.state").enabled = true
end

function M.disable()
  require("silentsaver.state").enabled = false
end

return M
