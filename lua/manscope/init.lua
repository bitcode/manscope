local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')  -- Require the logging module
local parse_man_pages = require('manscope.parse_man_pages')  -- Make sure this module exposes the right functions


-- Function to initialize the database and create tables if they don't exist
local function initialize_database()
    if not config.database_path then
        logger.log_to_file("Database path is not set", logger.LogLevel.ERROR)
        error("Database path is not set")
        return
    end
    logger.log_to_file("Attempting to open database at " .. config.database_path, logger.LogLevel.DEBUG)
    local db = sqlite3.open(config.database_path)
    if db == nil then
        logger.log_to_file("Failed to open database at " .. config.database_path, logger.LogLevel.ERROR)
        error("Failed to open database at " .. config.database_path)
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
      logger.log_to_file("Database initialized and tables created successfully at " .. config.database_path, logger.LogLevel.INFO)
      parse_man_pages.start_parsing()
  end

local M = {}
M.setup = function(opts)
    logger.log_to_file("Setting up Manscope with provided options.", logger.LogLevel.DEBUG)
    config = vim.tbl_deep_extend("force", config, opts or {})
    initialize_database()
end

return M
