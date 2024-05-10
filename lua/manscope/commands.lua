local function cycle_man_pages()
    logger.log_to_file("Cycling through man pages to check for updates.", logger.LogLevel.DEBUG)
    if parse_man_pages.check_for_updates_and_parse() then  -- Assumes this function checks for updates and parses
        logger.log_to_file("Man pages updated successfully.", logger.LogLevel.INFO)
    else
        logger.log_to_file("No updates were necessary or an error occurred.", logger.LogLevel.ERROR)
    end
end

vim.api.nvim_create_user_command('CycleManPages', cycle_man_pages, {desc = "Re-parse man pages and update the database"})
