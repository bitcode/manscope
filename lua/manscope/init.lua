local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')
local parse_man_pages = require('manscope.parse_man_pages') -- Make sure this path is correct
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

local function initialize_database()
    if not config.config.database_path then
        logger.log_to_file("Database path is not set", logger.LogLevel.ERROR)
        error("Database path is not set")
        return
    end
    logger.log_to_file("Attempting to open database at " .. config.config.database_path, logger.LogLevel.DEBUG)
    local db_path = vim.fn.expand(config.config.database_path)  -- Expand to resolve paths like ~/
    ensure_directory_exists(db_path)
    local db = sqlite3.open(db_path)
    if db == nil then
        logger.log_to_file("Failed to open database at " .. config.config.database_path, logger.LogLevel.ERROR)
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
        error("Failed to create tables: " .. db:errmsg())
    end

    db:exec[[
        INSERT INTO synonyms (term, synonym) VALUES ('copy', 'cp');
        -- Add more synonyms as needed
    ]]

    db:close()
    logger.log_to_file("Database initialized and tables created successfully at " .. config.config.database_path, logger.LogLevel.INFO)
    parse_man_pages.start_parsing() -- Ensure this function exists and is callable
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
