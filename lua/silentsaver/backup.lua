local M = {}

local uv = vim.uv

local function cfg()
  return require("silentsaver.config").options
end

local function is_windows()
  return vim.fn.has("win32") == 1
end

local function base_dir()
  return vim.fs.normalize(cfg().dir)
end

-- A sortable wall-clock timestamp: yyyymmdd_HHMMSS + milliseconds. Seconds and
-- milliseconds come from the same gettimeofday() reading so sub-second ordering
-- is consistent (mixing wall-clock seconds with a monotonic ms breaks sort).
local function timestamp()
  local sec, usec = uv.gettimeofday()
  return os.date("%Y%m%d_%H%M%S", sec) .. string.format("%03d", math.floor(usec / 1000))
end

-- Encode an absolute source directory into a backup-relative segment, dropping
-- the part that cannot live in a path (the Windows drive colon, the Unix root
-- slash). Reversed by `decode_dir`.
local function encode_dir(absdir)
  if is_windows() then
    return (absdir:gsub(":", "")) -- "C:/Users/x" -> "C/Users/x"
  end
  return (absdir:gsub("^/", "")) -- "/home/x" -> "home/x"
end

local function decode_dir(enc)
  if is_windows() then
    if enc:match("^%a$") then
      return enc .. ":" -- bare drive, e.g. "C" -> "C:"
    end
    return (enc:gsub("^(%a)/", "%1:/")) -- "C/Users/x" -> "C:/Users/x"
  end
  return "/" .. enc
end

---Backup destination for a source file. The per-file directory
---(`dirname(backup_path)`) is stable across calls; only the leaf timestamp moves.
---@param src string  absolute source path
---@return string
function M.backup_path(src)
  src = vim.fs.normalize(vim.fn.fnamemodify(src, ":p"))
  local dir = vim.fs.dirname(src)
  local base = vim.fs.basename(src)
  local ext = base:match("(%.[^.]*)$") or ""
  return table.concat({ base_dir(), encode_dir(dir), base, timestamp() .. ext }, "/")
end

---Reverse of `backup_path`: the original file a backup belongs to.
---@param backup string  absolute backup path
---@return string
function M.original_path(backup)
  backup = vim.fs.normalize(backup)
  local root = base_dir()
  local rel = backup:sub(#root + 2) -- strip "<root>/"
  -- rel = <encoded_dir>/<original_base>/<timestamp><ext>
  local without_ts = vim.fs.dirname(rel)
  local orig_base = vim.fs.basename(without_ts)
  local enc_dir = vim.fs.dirname(without_ts)
  return decode_dir(enc_dir) .. "/" .. orig_base
end

-- ── async fs helpers (safe in the libuv fast context) ──────────────────────

local function write_async(path, data, cb)
  uv.fs_open(path, "w", 420, function(oerr, fd) -- 0644
    if oerr or not fd then
      return cb(false)
    end
    uv.fs_write(fd, data, -1, function(werr)
      uv.fs_close(fd, function()
        cb(not werr)
      end)
    end)
  end)
end

local function read_async(path, cb)
  uv.fs_open(path, "r", 292, function(oerr, fd) -- 0444
    if oerr or not fd then
      return cb(nil)
    end
    uv.fs_fstat(fd, function(serr, stat)
      if serr or not stat then
        uv.fs_close(fd, function() end)
        return cb(nil)
      end
      uv.fs_read(fd, stat.size, 0, function(rerr, data)
        uv.fs_close(fd, function() end)
        cb(rerr and nil or data)
      end)
    end)
  end)
end

-- Names of regular files in `dir` (async). cb receives a sorted ascending list.
local function list_async(dir, cb)
  uv.fs_scandir(dir, function(err, handle)
    if err or not handle then
      return cb({})
    end
    local names = {}
    while true do
      local name, typ = uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if typ ~= "directory" then
        names[#names + 1] = name
      end
    end
    table.sort(names)
    cb(names)
  end)
end

-- Drop old backups in `outdir` per the retention policy. Async, best-effort.
local function prune(outdir)
  local r = cfg().retention or {}
  local maxn = r.max_per_file or 0
  local maxage = r.max_age_days or 0
  if maxn <= 0 and maxage <= 0 then
    return
  end
  list_async(outdir, function(names)
    if maxn > 0 and #names > maxn then
      for i = 1, #names - maxn do
        uv.fs_unlink(outdir .. "/" .. names[i], function() end)
      end
    end
    if maxage > 0 then
      local cutoff = os.date("%Y%m%d", os.time() - maxage * 86400)
      for _, name in ipairs(names) do
        local d = name:match("^(%d%d%d%d%d%d%d%d)")
        if d and d < cutoff then
          uv.fs_unlink(outdir .. "/" .. name, function() end)
        end
      end
    end
  end)
end

---Back up the current buffer if eligible. Disk I/O is asynchronous, so a save
---is never blocked. No-op when disabled, for ignored filetypes, for unnamed or
---non-file buffers, or (with `dedupe`) when the content is unchanged.
function M.run()
  local opts = cfg()
  if not require("silentsaver.state").enabled then
    return
  end
  if vim.tbl_contains(opts.ignore_filetypes or {}, vim.bo.filetype) then
    return
  end

  local src = vim.api.nvim_buf_get_name(0)
  if src == "" then
    return
  end
  src = vim.fs.normalize(vim.fn.fnamemodify(src, ":p"))
  if vim.fn.filereadable(src) == 0 then
    return
  end
  local root = base_dir()
  if src:sub(1, #root + 1) == root .. "/" then
    return -- never back up files inside the backup dir
  end

  local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local out = M.backup_path(src)
  local outdir = vim.fs.dirname(out)
  vim.fn.mkdir(outdir, "p") -- sync, main thread, cheap

  local function commit()
    write_async(out, content, function(ok)
      vim.schedule(function()
        if ok then
          require("silentsaver.log").info("backup " .. out)
          prune(outdir)
        else
          require("silentsaver.log").warn("backup failed: " .. out)
        end
      end)
    end)
  end

  if not opts.dedupe then
    return commit()
  end
  list_async(outdir, function(names)
    local latest = names[#names]
    if not latest then
      return commit()
    end
    read_async(outdir .. "/" .. latest, function(prev)
      if prev ~= content then
        commit()
      end
    end)
  end)
end

return M
