local M = {}

-- Assuming use of stdpath to align with Neovim's recommended practice for storing data.
local stdpath = vim.fn.stdpath('data')

M.config = {
    -- Construct the path using stdpath to ensure it respects Neovim's directory structure.
    database_path = stdpath .. '/manscope/manscope.db',  -- Store database in Neovim's data directory under 'manscope'.
    language = 'en',  -- Language of the man pages
    search_sensitivity = 'medium',  -- Example setting for search precision or fuzziness
}

return M
