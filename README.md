# Manscope

Manscope is a Telescope.nvim extension that enables context-aware searching through man pages directly from Neovim.

## Dependencies

- LuaRocks, is the package manager for Lua modules.

- Ubuntu 

`sudo apt install luarocks`

- To confirm installation:

`luarocks --version`

## Features

- Search through man pages with context awareness.
- Configurable search parameters.

## Installation

Install LuaRocks modules

`luarocks --local install lsqlite3`
`luarocks install luafilesystem`

Using lazy.nvim:

```lua
return {
  'bitcode/manscope',
  name = 'manscope',
  dependencies = { "nvim-telescope/telescope.nvim" },
  priority = 1000,
  config = function ()
  require('lazy').setup({
    {
        cmd = 'Telescope manscope',
        config = function()
            require('manscope').setup({
                --database_path = '/path/to/your/database/manscope.db',
                language = 'en',  -- Language setting for the man pages
                search_sensitivity = 'medium',  -- Adjust how sensitive the search is to variations
            })
            -- Set up the keybind for Manscope after the plugin is loaded
            vim.api.nvim_set_keymap('n', '<leader>fm', ':Telescope manscope<CR>', { noremap = true, silent = true })
        end
    }
})
  end
}
```
 
## Configuration

- `database_path`: This is set internally to use Neovim's standard data directory. If you need to customize this, you will need to modify the source code at `lua/manscope/config.lua`.
- `language`: Default language setting for man pages, currently set to 'en'.
- `search_sensitivity`: Adjusts how sensitive the search functionality is to variations in search terms.

## Usage

After installation, use the following command to search man pages:

```vim
:Telescope manscope
:CycleManPages
```

## Logging

The location of the log file is in `$HOME/.cache/nvim`

## SQLite database location

The location of the database file is in `stdpath('data')` usually `$HOME/.local/share/nvim/`
