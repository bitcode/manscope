local M = {}

M.config = {
    database_path = vim.fn.expand('~/.local/share/nvim/lazy/manscope/lua/manscope/manscope.db'),
    language = 'en',
    search_sensitivity = 'medium',
}

require('manscope.log_module').log_to_file("Loaded config with database_path: " .. M.config.database_path, require('manscope.log_module').LogLevel.DEBUG)

return M
