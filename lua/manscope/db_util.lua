local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')

local M = {}

function M.is_database_initialized()
    local db_path = vim.fn.expand(config.config.database_path)
    local db = sqlite3.open(db_path)
    if not db then
        logger.log_to_file("Failed to open database at " .. db_path, logger.LogLevel.ERROR)
        return false
    end

    local result = false
    for row in db:nrows("SELECT name FROM sqlite_master WHERE type='table' AND name='man_pages';") do
        if row.name == 'man_pages' then
            result = true
            break
        end
    end
    db:close()
    return result
end

return M
