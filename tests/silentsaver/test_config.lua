local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["defaults are applied without opts"] = function()
  local cfg = require("silentsaver.config")
  cfg.setup()
  eq(cfg.options.dedupe, true)
  eq(cfg.options.log_level, "warn")
  eq(type(cfg.options.events), "table")
end

T["user opts deep-merge over defaults"] = function()
  local cfg = require("silentsaver.config")
  cfg.setup({ diff_vertical = true, ignore_filetypes = { "log", "qf" } })
  eq(cfg.options.diff_vertical, true)
  eq(cfg.options.ignore_filetypes, { "log", "qf" })
  -- untouched defaults survive
  eq(cfg.options.dedupe, true)
  eq(cfg.options.retention.max_per_file, 0)
end

return T
