local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local parse_man_pages = require('manscope.parse_man_pages')
local lfs = require('lfs')
local db_util = require('manscope.db_util')
local logger = require('manscope.log_module')

if type(logger) ~= "table" then
    error("Failed to load log_module: logger is not a table")
end

local M = {}

local function ensure_directory_exists(file_path)
    logger.log_to_file("Ensuring directory exists for path: " .. file_path, logger.LogLevel.DEBUG)
    local dir_path = vim.fn.fnamemodify(file_path, ":h")
    if not lfs.attributes(dir_path) then
        local result, err = lfs.mkdir(dir_path)
        if not result then
            logger.log_to_file("Failed to create directory " .. dir_path .. ": " .. err, logger.LogLevel.ERROR)
            vim.notify("Failed to create directory " .. dir_path .. ": " .. err, vim.log.levels.ERROR)
            return false
        else
            logger.log_to_file("Created directory: " .. dir_path, logger.LogLevel.INFO)
        end
    end
    return true
end

local function async_initialize_database(callback)
    logger.log_to_file("Initializing database", logger.LogLevel.DEBUG)
    if not config.config.database_path then
        logger.log_to_file("Database path is not set", logger.LogLevel.ERROR)
        error("Database path is not set")
        return
    end
    logger.log_to_file("Attempting to open database at " .. config.config.database_path, logger.LogLevel.DEBUG)
    local db_path = vim.fn.expand(config.config.database_path)
    if not ensure_directory_exists(db_path) then
        vim.notify("Directory creation failed for " .. db_path, vim.log.levels.ERROR)
        return
    end

    db_util.set_initialization_in_progress(true)

    -- Run database initialization in a separate coroutine
    coroutine.wrap(function()
        logger.log_to_file("Started coroutine for database initialization", logger.LogLevel.DEBUG)
        local db = sqlite3.open(db_path)
        if db == nil then
            logger.log_to_file("Failed to open database at " .. config.config.database_path, logger.LogLevel.ERROR)
            db_util.set_initialization_in_progress(false)
            error("Failed to open database at " .. config.config.database_path)
        else
            logger.log_to_file("Database opened successfully", logger.LogLevel.INFO)
        end

        local sql_statements = [[
            CREATE VIRTUAL TABLE IF NOT EXISTS man_pages USING fts5(
                title, section, description UNINDEXED, content,
                version UNINDEXED, author UNINDEXED, format,
                language, file_path, environment
            );
            CREATE TABLE IF NOT EXISTS command_options (
                man_page_id INTEGER, option TEXT, description TEXT,
                FOREIGN KEY(man_page_id) REFERENCES man_pages(rowid)
            );
            CREATE TABLE IF NOT EXISTS man_page_relations (
                man_page_id INTEGER, related_page_id INTEGER, relation_type TEXT,
                FOREIGN KEY(man_page_id) REFERENCES man_pages(rowid),
                FOREIGN KEY(related_page_id) REFERENCES man_pages(rowid)
            );
            CREATE TABLE IF NOT EXISTS man_page_subsections (
                man_page_id INTEGER, subsection TEXT, extension TEXT,
                FOREIGN KEY(man_page_id) REFERENCES man_pages(rowid)
            );
            CREATE TABLE IF NOT EXISTS synonyms (
                term TEXT,
                synonym TEXT
            );
        ]]

        -- Database initialization SQL
        if db:exec(sql_statements) ~= sqlite3.OK then
            logger.log_to_file("Failed to create tables: " .. db:errmsg(), logger.LogLevel.ERROR)
            db:close()  -- Ensure the database is closed on failure
            db_util.set_initialization_in_progress(false)
            error("Failed to create tables: " .. db:errmsg())
        end

        if db:exec[[
            INSERT INTO synonyms (term, synonym) VALUES ('copy', 'cp');
            -- Add more synonyms as needed
        ]] ~= sqlite3.OK then
            logger.log_to_file("Failed to insert initial data: " .. db:errmsg(), logger.LogLevel.ERROR)
            db:close()  -- Ensure the database is closed on failure
            db_util.set_initialization_in_progress(false)
            error("Failed to insert initial data: " .. db:errmsg())
        end

        db:close()
        logger.log_to_file("Database initialized and tables created successfully at " .. config.config.database_path, logger.LogLevel.INFO)

        -- Continue with parsing
        parse_man_pages.start_parsing()
        db_util.set_initialization_in_progress(false)
        if callback then callback() end
    end)()
end

M.setup = function(opts)
    logger.log_to_file("Setting up Manscope with options", logger.LogLevel.DEBUG)
    -- Extend the default configuration with user-provided options
    config.config = vim.tbl_deep_extend("force", config.config, opts or {})

    -- Ensure the database path is expanded and set correctly
    config.config.database_path = vim.fn.expand(config.config.database_path or "")
    logger.log_to_file("Configuration loaded: Database path set to " .. tostring(config.config.database_path), logger.LogLevel.DEBUG)

    -- Initialize the database only after configuration has been updated
    async_initialize_database(function()
        vim.notify("Database initialization and parsing completed.", vim.log.levels.INFO)
    end)
end

return M
