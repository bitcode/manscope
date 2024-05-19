local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')  -- Require the logging module
local parse_man_pages = require('manscope.parse_man_pages')  -- Make sure this module exposes the right functions
local lfs = require('lfs')

-- Function to ensure the directory for the database file exists
local function ensure_directory_exists(file_path)
    local dir_path = vim.fn.fnamemodify(file_path, ":h")
    if not lfs.attributes(dir_path) then
        local result, err = lfs.mkdir(dir_path)
        if not result then
            logger.log_to_file("Failed to create directory " .. dir_path .. ": " .. err, logger.LogLevel.ERROR)
            return false
        else
            logger.log_to_file("Created directory: " .. dir_path, logger.LogLevel.INFO)
        end
    end
    return true
end

-- Function to initialize the database and create tables if they don't exist
local function initialize_database()
    local db_path = vim.fn.expand(config.config.database_path or "")

    if db_path == "" then
        logger.log_to_file("Database path is not set", logger.LogLevel.ERROR)
        error("Database path is not set")
        return
    end

    if not ensure_directory_exists(db_path) then
        error("Failed to ensure database directory exists")
        return
    end

    logger.log_to_file("Attempting to open database at " .. db_path, logger.LogLevel.DEBUG)
    local db = sqlite3.open(db_path)
    if db == nil then
        logger.log_to_file("Failed to open database at " .. db_path, logger.LogLevel.ERROR)
        error("Failed to open database at " .. db_path)
    else
        logger.log_to_file("Database opened successfully", logger.LogLevel.INFO)
    end

    local sql_statements = [[
        CREATE VIRTUAL TABLE IF NOT EXISTS man_pages USING fts5(
            title, section, description UNINDEXED, content,
            version UNINDEXED, author UNINDEXED, format TEXT,
            language TEXT DEFAULT 'en', file_path TEXT, environment TEXT
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
        error("Failed to create tables: " .. db:errmsg())
    end

    db:exec[[
        INSERT INTO synonyms (term, synonym) VALUES ('copy', 'cp');
        -- Add more synonyms as needed
    ]]

    db:close()
    logger.log_to_file("Database initialized and tables created successfully at " .. db_path, logger.LogLevel.INFO)
    parse_man_pages.start_parsing()
end

local M = {}

M.setup = function(opts)
    -- Extend the default configuration with user-provided options
    config.config = vim.tbl_deep_extend("force", config.config, opts or {})

    -- Ensure the database path is expanded and set correctly
    config.config.database_path = vim.fn.expand(config.config.database_path or "")

    logger.log_to_file("Configuration loaded: Database path set to " .. tostring(config.config.database_path), logger.LogLevel.DEBUG)

    -- Initialize the database only after configuration has been updated
    initialize_database()
end

return M
