-- Interactive bootstrap: put silentsaver + mini.test on the runtimepath, then
-- open Neovim so you can run `:lua MiniTest.run()` by hand.
-- Usage: nvim --noplugin -u scripts/minitest_init.lua
local root = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.expand("<sfile>:p")), ":h:h")
vim.opt.runtimepath:prepend(root)

local candidates = {}
if vim.env.MINI_NVIM then
  candidates[#candidates + 1] = vim.env.MINI_NVIM
end
candidates[#candidates + 1] = root .. "/deps/mini.nvim"
candidates[#candidates + 1] = vim.fn.stdpath("data") .. "/lazy/mini.nvim"
candidates[#candidates + 1] = vim.fn.stdpath("data") .. "/site/pack/deps/start/mini.nvim"
for _, p in ipairs(candidates) do
  if vim.fn.isdirectory(p) == 1 then
    vim.opt.runtimepath:prepend(p)
    break
  end
end

require("mini.test").setup()
