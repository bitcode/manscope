local parse_man_pages = require('manscope.parse_man_pages')  -- Ensure this module is correctly required

local function cycle_man_pages()
    logger.log_to_file("Cycling through man pages to check for updates.", logger.LogLevel.DEBUG)
    parse_man_pages.start_parsing()  -- This should trigger the new directory processing
    logger.log_to_file("Man pages updated successfully.", logger.LogLevel.INFO)
end

vim.api.nvim_create_user_command('CycleManPages', cycle_man_pages, {desc = "Re-parse man pages and update the database"})
