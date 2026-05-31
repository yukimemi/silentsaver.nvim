local M = {}

---Register the `:SilentSaver*` user commands. Safe to call more than once.
function M.register()
  local function cmd(name, fn, desc)
    vim.api.nvim_create_user_command(name, fn, { desc = desc })
  end

  cmd("SilentSaverBackup", function()
    require("silentsaver.backup").run()
  end, "silentsaver: back up the current buffer now")

  cmd("SilentSaverOpen", function()
    require("silentsaver.open").open()
  end, "silentsaver: browse backups of the current file")

  cmd("SilentSaverDiff", function()
    require("silentsaver.open").diff()
  end, "silentsaver: diff a backup against its original")

  cmd("SilentSaverEnable", function()
    require("silentsaver.state").enabled = true
    require("silentsaver.log").echo("automatic backup enabled")
  end, "silentsaver: resume automatic backups")

  cmd("SilentSaverDisable", function()
    require("silentsaver.state").enabled = false
    require("silentsaver.log").echo("automatic backup disabled")
  end, "silentsaver: pause automatic backups")

  cmd("SilentSaverToggle", function()
    local state = require("silentsaver.state")
    state.enabled = not state.enabled
    require("silentsaver.log").echo(state.enabled and "automatic backup enabled" or "automatic backup disabled")
  end, "silentsaver: toggle automatic backups")
end

return M
