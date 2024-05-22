<img src="https://img.shields.io/github/license/is0n/jaq-nvim?style=for-the-badge&logo=GNU" align="right"/>

<h1 align='center'>runner-nvim</h1>

## Installation:

#### packer:
```lua
use {"devallabharath/runner-nvim"}
```

#### Lazy:
```lua
{
  "devallabharath/runner.nvim",
  event = 'VeryLazy',
  require('runner').setup({
    -- config
  })
}
```

## Example Lua Config:

```lua
require('runner').setup{
  cmds = {
    -- Uses vim commands
    internal = {
      lua = "luafile %",
      vim = "source %"
    },

    -- Uses shell commands
    external = {
      markdown = "glow %",
      python   = "python3 %",
      go       = "go run %",
      sh       = "sh %"
    }
  },

  behavior = {
    -- Default type
    default     = "float",

    -- Start in insert mode
    startinsert = false,

    -- Use `wincmd p` on startup
    wincmd      = false,

    -- Auto-save files
    autosave    = false
  },

  ui = {
    float = {
      -- See ':h nvim_open_win'
      border    = "none",

      -- See ':h winhl'
      winhl     = "Normal",
      borderhl  = "FloatBorder",

      -- See ':h winblend'
      winblend  = 0,

      -- Num from `0-1` for measurements
      height    = 0.8,
      width     = 0.8,
      x         = 0.5,
      y         = 0.5
    },

    terminal = {
      -- Window position
      position = "bot",

      -- Window size
      size     = 10,

      -- Disable line numbers
      line_no  = false
    },

    quickfix = {
      -- Window position
      position = "bot",

      -- Window size
      size     = 10
    }
  }
}
```

## Example JSON Config:

```json
{
  "internal": {
    "lua": "luafile %",
    "vim": "source %"
  },

  "external": {
    "markdown": "glow %",
    "python": "python3 %",
    "go": "go run %",
    "sh": "sh %"
  }
}
```

In the current working directory, `Runner` will search for a file called `.runner.json`.

This config file will be used for running commands, both external and internal.

## Usage:

`:Runner` by default uses the `float` type to run code. The default can be changed (see `Example Lua Config`).

Available modes: `Bang`, `Terminal`, `Float`, `Quickfix`

`:Runner bang`: opens at the bottom of the screen

`:Runner float`: opens in the float

`:Runner terminal`: opens in the terminal

`:Runner quickfix`: opens in the quickfix split

The commands for `:Runner` also have certain variables that can help in running code.

You can put any of the following in `require('runner').setup()` or `.runner.json` ...

- `%` / `$file`    • Current File
- `#` / `$altFile` • Alternate File
- `$dir`           • Current Working Directory
- `$filePath`      • Path to Current File
- `$fileBase`      • Basename of File (no extension)
- `$moduleName`    • Python Module Name
