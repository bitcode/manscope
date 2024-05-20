-- File: ./lua/manscope/commands.lua
local logger = require('manscope.log_module')
local parse_man_pages = require('manscope.parse_man_pages')
local db_util = require('manscope.db_util')

local function cycle_man_pages()
    if not db_util.is_database_initialized() then
        vim.notify("Database is not initialized. Run the setup first.", vim.log.levels.ERROR)
        logger.log_to_file("CycleManPages: Database is not initialized.", logger.LogLevel.ERROR)
        return
    end

    vim.notify("Cycling through man pages to check for updates...", vim.log.levels.INFO)
    logger.log_to_file("Cycling through man pages to check for updates.", logger.LogLevel.DEBUG)

    local success, err = pcall(parse_man_pages.start_parsing)
    if success then
        vim.notify("Man pages updated successfully.", vim.log.levels.INFO)
        logger.log_to_file("Man pages updated successfully.", logger.LogLevel.INFO)
    else
        vim.notify("Failed to update man pages: " .. tostring(err), vim.log.levels.ERROR)
        logger.log_to_file("Failed to update man pages: " .. tostring(err), logger.LogLevel.ERROR)
    end
end

vim.api.nvim_create_user_command('CycleManPages', cycle_man_pages, {desc = "Re-parse man pages and update the database"})
