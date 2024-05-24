local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')

local M = {}

local initialization_in_progress = false

function M.is_database_initialized()
    logger.log_to_file("Checking if database is initialized", logger.LogLevel.DEBUG)
    if initialization_in_progress then
        logger.log_to_file("Database initialization is in progress.", logger.LogLevel.INFO)
        return false
    end

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
    logger.log_to_file("Database initialized: " .. tostring(result), logger.LogLevel.DEBUG)
    return result
end

function M.set_initialization_in_progress(state)
    initialization_in_progress = state
    logger.log_to_file("Set initialization_in_progress to " .. tostring(state), logger.LogLevel.DEBUG)
end

return M
