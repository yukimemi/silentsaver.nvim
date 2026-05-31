-- Eager registration so the `:SilentSaver*` commands work without calling
-- `require("silentsaver").setup()` (convention over configuration). Automatic
-- backups (the autocmd) only start from `setup()`.
if vim.g.loaded_silentsaver then
  return
end
vim.g.loaded_silentsaver = true

require("silentsaver.command").register()
