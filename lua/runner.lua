local M = {}
local v = vim
local fn = v.fn
local api = v.api
local config = {
  cmds = {
    internal = {},
    external = {}
  },

  behavior = {
    default     = "float",
    startinsert = false,
    wincmd      = false,
    autosave    = false
  },

  ui = {
    float = {
      border    = "none",
      winhl     = "Normal",
      borderhl  = "FloatBorder",
      height    = 0.8,
      width     = 0.8,
      x         = 0.5,
      y         = 0.5,
      winblend  = 0
    },

    terminal = {
      position = "bot",
      line_no  = false,
      size     = 10
    },

    quickfix = {
      position = "bot",
      size     = 10
    }
  }
}

function M.setup(user_opts)
  config = v.tbl_deep_extend("force", config, user_opts)
end

local function dimensions(opts)
  local cl = v.o.columns
  local ln = v.o.lines

  local width = math.ceil(cl * opts.ui.float.width)
  local height = math.ceil(ln * opts.ui.float.height - 4)

  local col = math.ceil((cl - width) * opts.ui.float.x)
  local row = math.ceil((ln - height) * opts.ui.float.y - 1)

  return {
    width = width,
    height = height,
    col = col,
    row = row
  }
end

local function resize()
  local dim = dimensions(config)
  api.nvim_win_set_config(M.win, {
    style    = "minimal",
    relative = "editor",
    border   = config.ui.float.border,
    height   = dim.height,
    width    = dim.width,
    col      = dim.col,
    row      = dim.row
  })
end

local function float(cmd)
  local dim = dimensions(config)

  function M.VimResized()
    resize()
  end

  M.buf = api.nvim_create_buf(false, true)
  M.win = api.nvim_open_win(M.buf, true, {
    style    = "minimal",
    relative = "editor",
    border   = config.ui.float.border,
    height   = dim.height,
    width    = dim.width,
    col      = dim.col,
    row      = dim.row
  })

  api.nvim_win_set_option(M.win, "winhl", ("Normal:%s"):format(config.ui.float.winhl))
  api.nvim_win_set_option(M.win, "winhl", ("FloatBorder:%s"):format(config.ui.float.borderhl))
  api.nvim_win_set_option(M.win, "winblend", config.ui.float.winblend)

  api.nvim_buf_set_option(M.buf, "filetype", "Runner")
  api.nvim_buf_set_keymap(M.buf, 'n', '<ESC>', '<cmd>:lua vim.api.nvim_win_close(' .. M.win .. ', true)<CR>', { silent = true })

  fn.termopen(cmd)

  v.cmd("autocmd! VimResized * lua require('runner').VimResized()")

  if config.behavior.startinsert then
    v.cmd("startinsert")
  end

  if config.behavior.wincmd then
    v.cmd("wincmd p")
  end
end

local function term(cmd)
  v.cmd(config.ui.terminal.position .. " " .. config.ui.terminal.size .. "new | term " .. cmd)

  M.buf = api.nvim_get_current_buf()

  api.nvim_buf_set_option(M.buf, "filetype", "Runner")
  api.nvim_buf_set_keymap(M.buf, 'n', '<ESC>', '<cmd>:bdelete!<CR>', { silent = true })

  if config.behavior.startinsert then
    v.cmd("startinsert")
  end

  if not config.ui.terminal.line_no then
    v.cmd("setlocal nonumber | setlocal norelativenumber")
  end

  if config.behavior.wincmd then
    v.cmd("wincmd p")
  end
end

local function quickfix(cmd)
  v.cmd(
    'cex system("' .. cmd .. '") | ' ..
    config.ui.quickfix.position ..
    ' copen ' ..
    config.ui.quickfix.size)

  if config.behavior.wincmd then
    v.cmd("wincmd p")
  end
end

local function substitute(cmd)
  cmd = cmd:gsub("%%", '"' .. fn.expand('%') .. '"');
  cmd = cmd:gsub("$fileBase", '"' .. fn.expand('%:r') .. '"');
  cmd = cmd:gsub("$filePath", '"' .. fn.expand('%:p') .. '"');
  cmd = cmd:gsub("$file", '"' .. fn.expand('%') .. '"');
  cmd = cmd:gsub("$dir", '"' .. fn.expand('%:p:h') .. '"');
  cmd = cmd:gsub("$moduleName",
    '"' .. fn.substitute(fn.substitute(fn.fnamemodify(fn.expand("%:r"), ":~:."), "/", ".", "g"), "\\", ".",
      "g") .. '"');
  cmd = cmd:gsub("#", '"' .. fn.expand('#') .. '"');
  cmd = cmd:gsub("$altFile", '"' .. fn.expand('#') .. '"')
  return cmd
end

local function internal(cmd)
  cmd = cmd or config.cmds.internal[v.bo.filetype]

  if not cmd then
    v.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    v.cmd("silent write")
  end

  cmd = substitute(cmd)
  v.cmd(cmd)
end

local function run(type, cmd)
  cmd = cmd or config.cmds.external[v.bo.filetype]

  if not cmd then
    v.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    v.cmd("silent write")
  end

  cmd = substitute(cmd)
  if type == "float" then
    float(cmd)
    return
  elseif type == "bang" then
    v.cmd("!" .. cmd)
    return
  elseif type == "quickfix" then
    quickfix(cmd)
    return
  elseif type == "terminal" then
    term(cmd)
    return
  end

  v.cmd("echohl ErrorMsg | echo 'Error: Invalid type' | echohl None")
end

local function project(type, file)
  local json = file:read("*a")
  local status, table = pcall(fn.json_decode, json)
  io.close(file)

  if not status then
    v.cmd("echohl ErrorMsg | echo 'Error: Invalid json' | echohl None")
    return
  end

  if type == "internal" then
    local cmd = table.internal[v.bo.filetype]
    cmd = substitute(cmd)

    internal(cmd)
    return
  end

  local cmd = table.external[v.bo.filetype]
  cmd = substitute(cmd)

  run(type, cmd)
end

function M.Runner(type)
  local file = io.open(fn.expand('%:p:h') .. "/.runner.json", "r")

  -- Check if the filetype is in config.cmds.internal
  if v.tbl_contains(v.tbl_keys(config.cmds.internal), v.bo.filetype) then
    -- Exit if the type was passed and isn't "internal"
    if type and type ~= "internal" then
      v.cmd("echohl ErrorMsg | echo 'Error: Invalid type for internal command' | echohl None")
      return
    end
    type = "internal"
  else
    type = type or config.behavior.default
  end

  if file then
    project(type, file)
    return
  end

  if type == "internal" then
    internal()
    return
  end

  run(type)
end

return M
