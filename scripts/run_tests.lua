-- Headless mini.test runner with proper exit codes.
-- Usage: nvim -u NONE -l scripts/run_tests.lua [tests/silentsaver/test_foo.lua ...]
-- With no file argument, runs every test under tests/.

local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)

local function add_mini()
  -- Build without nil holes: a leading nil (e.g. unset $MINI_NVIM) would make
  -- ipairs stop immediately.
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
      return true
    end
  end
  return false
end

if not add_mini() then
  io.stderr:write("mini.nvim not found (set $MINI_NVIM or clone into deps/mini.nvim)\n")
  vim.cmd("cquit 1")
end

require("mini.test").setup()

local files = {}
for i = 1, #_G.arg do
  files[#files + 1] = _G.arg[i]
end

local run_opts = { execute = { reporter = MiniTest.gen_reporter.stdout() } }
if #files > 0 then
  MiniTest.run_file(files[1], run_opts)
else
  MiniTest.run(run_opts)
end

local failed = 0
for _, case in ipairs(MiniTest.current.all_cases or {}) do
  local state = case.exec and case.exec.state or ""
  if type(state) == "string" and state:find("^Fail") then
    failed = failed + 1
  end
end

if failed > 0 then
  vim.cmd("cquit " .. math.min(failed, 255))
else
  vim.cmd("qall!")
end
