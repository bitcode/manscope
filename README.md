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
        'bitcode/manscope',  
        cmd = 'Telescope manscope',  
        config = function()
            require('manscope').setup({
                context_lines = 10,  -- Example of a configurable option
                commands = {
                    apropos = "apropos",
                    man = "man",
                    rg = "rg --color=never"
                }
            })
            -- Set up the keybind for Manscope after the plugin is loaded
            vim.api.nvim_set_keymap('n', '<leader>ms', ':Telescope manscope<CR>', { noremap = true, silent = true })
        end
    }
})
```
 
made with chatgipittie good luck
