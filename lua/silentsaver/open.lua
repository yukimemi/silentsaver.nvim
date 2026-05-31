local M = {}

local function cfg()
  return require("silentsaver.config").options
end

local function current_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(name, ":p"))
end

---List the backups of the current file, newest first.
---@param src string
---@return string[]
local function backups_of(src)
  local outdir = vim.fs.dirname(require("silentsaver.backup").backup_path(src))
  if vim.fn.isdirectory(outdir) == 0 then
    return {}
  end
  local files = {}
  for name, typ in vim.fs.dir(outdir) do
    if typ == "file" then
      files[#files + 1] = outdir .. "/" .. name
    end
  end
  table.sort(files, function(a, b)
    return a > b
  end)
  return files
end

---Browse the backups of the current file (quickfix, or `vim.ui.select`).
function M.open()
  local src = current_file()
  if not src or vim.fn.filereadable(src) == 0 then
    require("silentsaver.log").echo("not a readable file", vim.log.levels.WARN)
    return
  end

  local files = backups_of(src)
  if #files == 0 then
    require("silentsaver.log").echo("no backups for " .. src, vim.log.levels.INFO)
    return
  end

  if cfg().use_ui_select then
    vim.ui.select(files, { prompt = "silentsaver: backups of " .. vim.fs.basename(src) }, function(choice)
      if choice then
        vim.cmd.edit(vim.fn.fnameescape(choice))
      end
    end)
  else
    local items = {}
    for _, f in ipairs(files) do
      items[#items + 1] = { filename = f, lnum = 1, text = f }
    end
    vim.fn.setqflist({}, "r")
    vim.fn.setqflist({}, "a", { title = "[backups of " .. src .. "]", items = items })
    vim.cmd("botright copen")
  end
end

---Diff the current buffer (assumed to be a backup) against its original file.
function M.diff()
  local cur = current_file()
  if not cur then
    return
  end
  local original = require("silentsaver.backup").original_path(cur)
  local split = cfg().diff_vertical and "vertical diffsplit " or "diffsplit "
  vim.cmd(split .. vim.fn.fnameescape(original))
end

return M
