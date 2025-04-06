local Path = require("plenary.path")
local M = {}

local cache_dir = vim.fn.stdpath("data") .. "/jumpr/"

---@class jumpr.Dir
---@field root string

---@class jumpr.File
---@field path string The path to the saved file

---@alias jumpr.Table table<string, jumpr.File>

local function init_dir() vim.fn.mkdir(cache_dir, "p") end

---@param dir string
---@return string
local function format_dir(dir)
  dir = string.gsub(dir, "/", "", 1)
  dir = string.gsub(dir, "/$", "")
  dir = string.gsub(dir, "/", "_")
  return dir .. ".json"
end

-- Get cwd as a custom-formatted filepath
---@return string
local function cwd_file() return format_dir(vim.fn.getcwd()) end

-- What the cache file should be named
local function get_cache_file()
  init_dir()
  local path = Path:new(cache_dir .. cwd_file())
  if not path:exists() then path:write("{}", "w") end
  return path
end

---@return jumpr.Table
local function get_cache()
  local path = get_cache_file()
  ---@type table
  local data = path:read()

  local cache = vim.fn.json_decode(data)
  return cache
end

--Save cache
---@param cache jumpr.Table
local function save(cache) get_cache_file():write(vim.fn.json_encode(cache), "w") end

-- Adds file to cache
local function add()
  local buf = vim.api.nvim_buf_get_name(0)
  local cache = get_cache()
  local toSave = { path = buf }
  cache[toSave.path] = toSave
  save(cache)
end

-- Removes file from cache if it exists
---@param file jumpr.File
local function remove(file)
  local cache = get_cache()
  cache[file.path] = nil
  save(cache)
end

-- Show saved paths
local function show()
  local cache = get_cache()
  local keys = {}
  for key, _ in pairs(cache) do
    table.insert(keys, key)
  end

  local width = math.floor(vim.o.columns * 0.5)
  local height = math.floor(vim.o.lines * 0.5)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, keys)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })

  ---@type vim.api.keyset.win_config
  local config = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = "jumpr",
  }

  local win = vim.api.nvim_open_win(buf, true, config)

  vim.api.nvim_buf_set_keymap(
    buf,
    "n",
    "<Esc>",
    "",
    { desc = "Close window", callback = function() vim.api.nvim_win_close(win, true) end }
  )
end

M.setup = function(opts)
  vim.api.nvim_create_user_command("JumprShow", show, opts or {})
  vim.api.nvim_create_user_command("JumprSet", function() add() end, opts or {})
  vim.api.nvim_create_user_command("JumprLoad", get_cache, opts or {})
  vim.api.nvim_create_user_command("JumprRemove", function()
    local buf = vim.api.nvim_buf_get_name(0)
    remove({ path = buf })
  end, opts or {})
end

return M
