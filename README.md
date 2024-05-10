# Manscope

Manscope is a Telescope.nvim extension that enables context-aware searching through man pages directly from Neovim.

## Features

- Search through man pages with context awareness.
- Configurable search parameters.

## Installation

Using lazy.nvim:

```lua
require('lazy').setup({
    {
        'yourgithubusername/manscope',  -- Update with actual GitHub path
        cmd = 'Telescope manscope',
        config = function()
            require('manscope').setup({
                database_path = '/path/to/your/database/manscope.db',
                language = 'en',  -- Language setting for the man pages
                search_sensitivity = 'medium',  -- Adjust how sensitive the search is to variations
            })
            -- Set up the keybind for Manscope after the plugin is loaded
            vim.api.nvim_set_keymap('n', '<leader>ms', ':Telescope manscope<CR>', { noremap = true, silent = true })
        end
    }
})
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
