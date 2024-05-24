local M = {}

M.config = {
    database_path = vim.fn.expand('~/.local/share/nvim/lazy/manscope/lua/manscope/manscope.db'),
    language = 'en',
    search_sensitivity = 'medium',
}

return M
