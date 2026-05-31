local M = {}

local AUGROUP = "silentsaver"

---Install the backup autocmd. Idempotent: clears the augroup on re-setup.
function M.register()
  local options = require("silentsaver.config").options
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  if options.events and #options.events > 0 then
    vim.api.nvim_create_autocmd(options.events, {
      group = group,
      callback = function()
        require("silentsaver.backup").run()
      end,
    })
  end
end

function M.unregister()
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
end

return M
