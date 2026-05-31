local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      require("silentsaver.config").setup({ dir = vim.fn.tempname() })
      require("silentsaver.state").enabled = true
    end,
  },
})

T["backup_path round-trips through original_path"] = function()
  local backup = require("silentsaver.backup")
  local src = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.tempname() .. "/proj/note.txt", ":p"))
  eq(backup.original_path(backup.backup_path(src)), src)
end

T["backup_path keeps a stable per-file directory"] = function()
  local backup = require("silentsaver.backup")
  local src = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.tempname() .. "/a/b.lua", ":p"))
  local d1 = vim.fs.dirname(backup.backup_path(src))
  local d2 = vim.fs.dirname(backup.backup_path(src))
  eq(d1, d2)
  eq(vim.fs.basename(d1), "b.lua")
end

local function list_backups(outdir)
  local files = {}
  if vim.fn.isdirectory(outdir) == 1 then
    for name, typ in vim.fs.dir(outdir) do
      if typ == "file" then
        files[#files + 1] = name
      end
    end
  end
  table.sort(files)
  return files
end

-- Content of the newest backup, or nil. Used to wait on the *fully written*
-- file rather than its mere appearance (fs_open precedes fs_write).
local function latest_content(outdir)
  local files = list_backups(outdir)
  if #files == 0 then
    return nil
  end
  local rf = io.open(outdir .. "/" .. files[#files], "r")
  if not rf then
    return nil
  end
  local data = rf:read("*a")
  rf:close()
  return data
end

T["run backs up, dedupe skips identical, change adds a version"] = function()
  local backup = require("silentsaver.backup")

  local srcdir = vim.fn.tempname()
  vim.fn.mkdir(srcdir, "p")
  local src = srcdir .. "/note.txt"
  local fd = assert(io.open(src, "w"))
  fd:write("hello\nworld")
  fd:close()
  vim.cmd.edit(vim.fn.fnameescape(src))

  -- derive outdir from the buffer name run() will see (the path may be
  -- canonicalized, e.g. macOS /tmp -> /private/tmp)
  local bufname = vim.fs.normalize(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"))
  local outdir = vim.fs.dirname(backup.backup_path(bufname))

  backup.run()
  vim.wait(2000, function()
    return latest_content(outdir) == "hello\nworld"
  end, 20)
  eq(#list_backups(outdir), 1)

  -- identical buffer -> deduped, no new backup
  backup.run()
  vim.wait(300)
  eq(#list_backups(outdir), 1)

  -- changed buffer -> a new version
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello", "world", "changed" })
  backup.run()
  vim.wait(2000, function()
    return latest_content(outdir) == "hello\nworld\nchanged"
  end, 20)
  eq(#list_backups(outdir), 2)
  eq(latest_content(outdir), "hello\nworld\nchanged")
end

T["disabled state suppresses backups"] = function()
  local backup = require("silentsaver.backup")
  require("silentsaver.state").enabled = false

  local srcdir = vim.fn.tempname()
  vim.fn.mkdir(srcdir, "p")
  local src = srcdir .. "/x.txt"
  local fd = assert(io.open(src, "w"))
  fd:write("data")
  fd:close()
  vim.cmd.edit(vim.fn.fnameescape(src))

  local bufname = vim.fs.normalize(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p"))
  local outdir = vim.fs.dirname(backup.backup_path(bufname))
  backup.run()
  vim.wait(300)
  eq(#list_backups(outdir), 0)
end

return T
