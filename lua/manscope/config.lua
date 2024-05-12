local M = {}

M.config = {
    -- Construct the path using stdpath to ensure it respects Neovim's directory structure.
    database_path = '~/.local/share/nvim/lazy/manscope/lua/manscope/manscope.db',
    language = 'en',  -- Language of the man pages
    search_sensitivity = 'medium',  -- Example setting for search precision or fuzziness
}

return M
