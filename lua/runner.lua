local M = {}
local v = vim
local fn = v.fn
local api = v.api
local config = {
  cmds = {},
  behavior = {
    default     = "float",
    startinsert = false,
    wincmd      = false,
    autosave    = false,
    terminal_cmd    = "default"
  },
  ui = {
    float = {
      border   = "none",
      winhl    = "Normal",
      borderhl = "FloatBorder",
      height   = 0.8,
      width    = 0.8,
      x        = 0.5,
      y        = 0.5,
      winblend = 0
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
    row      = dim.row,
    title    = " " .. cmd .. " "
  })

  api.nvim_win_set_option(M.win, "winhl", ("Normal:%s"):format(config.ui.float.winhl))
  api.nvim_win_set_option(M.win, "winhl", ("FloatBorder:%s"):format(config.ui.float.borderhl))
  api.nvim_win_set_option(M.win, "winblend", config.ui.float.winblend)

  api.nvim_buf_set_option(M.buf, "filetype", "Runner")
  api.nvim_buf_set_keymap(M.buf, 'n', '<ESC>', '<cmd>:lua vim.api.nvim_win_close(' .. M.win .. ', true)<CR>',
    { silent = true })

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
  local terminal_cmd = config.behavior.terminal_cmd
  if terminal_cmd ~= 'default' then
    return v.cmd(string.format("%s %s", terminal_cmd, cmd))
  end
  v.cmd(config.ui.terminal.position .. " " .. config.ui.terminal.size .. "new")
  v.fn.termopen(cmd)

  M.buf = api.nvim_get_current_buf()

  api.nvim_buf_set_option(M.buf, "filetype", "Runner")
  api.nvim_buf_set_keymap(M.buf, 'n', '<ESC>', '<cmd>:bdelete!<CR>', { silent = true })

  if config.behavior.startinsert then
    v.cmd("startinsert")
  end

  if not config.ui.terminal.line_no then
    v.opt_local.number = false
    v.opt_local.relativenumber = false
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

local function formatCmd(cmd)
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

local function executeCmd(mode, cmd)
  if cmd == nil then return end
  if cmd:sub(1, 1) == ":" then
    mode = "internal"
  end
  cmd = formatCmd(cmd)
  if mode == "float" then
    float(cmd)
  elseif mode == "bang" then
    v.cmd("!" .. cmd)
  elseif mode == "quickfix" then
    quickfix(cmd)
  elseif mode == "terminal" then
    term(cmd)
  elseif type == "internal" then
    v.cmd(cmd)
  else
    v.cmd("echohl ErrorMsg | echo 'Error: Invalid type' | echohl None")
  end
end

local function makeList(data)
  local list = {}
  for key, val in pairs(data) do
    table.insert(list, key .. " :: " .. val)
  end
  return list
end

local function run(mode, cmd)
  cmd = cmd or config.cmds[v.bo.filetype]

  if not cmd then
    v.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
    return
  end

  if config.behavior.autosave then
    v.cmd("silent write")
  end

  if type(cmd) == "table" then
    v.ui.select(
      makeList(cmd),
      { prompt = "Select a command ", kind = "Runner" },
      function(selected)
        executeCmd(mode, selected:match(" :: (.*)$"))
      end
    )
  else
    executeCmd(mode, cmd)
  end
end

local function run_custom(mode)
  if config.behavior.autosave then
      v.cmd("silent write")
  end

  v.ui.input(
    { prompt = "Run command ", kind = "Runner" },
    function(input)
      executeCmd(mode, input)
    end
  )
end

local function project(mode, file)
  local json = file:read("*a")
  local status, table = pcall(fn.json_decode, json)
  io.close(file)

  if not status then
    v.cmd("echohl ErrorMsg | echo 'Error: Invalid json' | echohl None")
    return
  end

  local cmd = table.cmds[v.bo.filetype]
  cmd = formatCmd(cmd)
  run(mode, cmd)
end

function M.Runner(mode)
  local file = io.open(fn.expand('%:p:h') .. "/.runner.json", "r")
  mode = mode or config.behavior.default

  if file then
    project(mode, file)
    return
  end

  run(mode)
end

function M.RunnerRun(mode)
  mode = mode or config.behavior.default
  run_custom(mode)
end

return M
