local M = {}

local NAME_TO_LEVEL = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

local function threshold()
  local name = require("silentsaver.config").options.log_level
  return NAME_TO_LEVEL[name] or vim.log.levels.WARN
end

---Background log. Shown only when `notify = true` and `level >= log_level`, so
---`notify = false` makes silentsaver truly silent (backups happen quietly).
---@param level integer
---@param msg string
function M.at(level, msg)
  if not require("silentsaver.config").options.notify then
    return
  end
  if level < threshold() then
    return
  end
  vim.notify(msg, level, { title = "silentsaver" })
end

function M.debug(msg)
  M.at(vim.log.levels.DEBUG, msg)
end

function M.info(msg)
  M.at(vim.log.levels.INFO, msg)
end

function M.warn(msg)
  M.at(vim.log.levels.WARN, msg)
end

function M.error(msg)
  M.at(vim.log.levels.ERROR, msg)
end

---User-initiated feedback (from a `:SilentSaver*` command). Always shown.
---@param msg string
---@param level? integer
function M.echo(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "silentsaver" })
end

return M
