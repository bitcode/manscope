local lfs = require('lfs')
local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')  -- Include the logging module

-- Function to check if a directory exists and is accessible
local function directory_exists(path)
    local ok, err, code = os.rename(path, path)
    if not ok then
        if code == 13 then
            -- Permission denied, but directory exists
            return true
        end
    end
    return ok, err
end

-- Function to get directories from MANPATH environment variable
local function get_man_directories_from_env()
    local manpath = os.getenv("MANPATH")
    logger.log_to_file("MANPATH: " .. (manpath or "not set"), logger.LogLevel.DEBUG)
    if manpath and #manpath > 0 then
        local paths = vim.split(manpath, ':', true)
        for _, path in ipairs(paths) do
            logger.log_to_file("From ENV: " .. path, logger.LogLevel.DEBUG)
        end
        return paths
    else
        return {}
    end
end

-- Function to read directories from /etc/manpath.config
local function get_man_directories_from_config()
    local paths = {}
    local file = io.open("/etc/manpath.config", "r")
    if file then
        for line in file:lines() do
            local mandatory_path = line:match("^MANDATORY_MANPATH%s+(.+)$")
            local map_path = line:match("^MANPATH_MAP%s+%S+%s+(.+)$")
            if mandatory_path then
                table.insert(paths, mandatory_path)
                logger.log_to_file("From Config MANDATORY: " .. mandatory_path, logger.LogLevel.DEBUG)
            elseif map_path then
                table.insert(paths, map_path)
                logger.log_to_file("From Config MAP: " .. map_path, logger.LogLevel.DEBUG)
            end
        end
        file:close()
    else
        logger.log_to_file("Failed to open /etc/manpath.config", logger.LogLevel.ERROR)
    end
    return paths
end

-- Consolidate all directories to be processed
local function get_man_directories()
    local paths = get_man_directories_from_env()
    for _, path in ipairs(get_man_directories_from_config()) do
        table.insert(paths, path)
        logger.log_to_file("Added to processing list: " .. path, logger.LogLevel.DEBUG)
    end
    return paths
end

-- Calculate checksum of file content
local function calculate_checksum(input)
    local checksum = 0
    for i = 1, #input do
        checksum = (checksum + string.byte(input, i)) % 65536
    end
    return checksum
end

-- Check if the file is a valid man page
local function is_valid_man_page(file)
    local command = "man --whatis " .. vim.fn.shellescape(file)
    local output = vim.fn.system(command)

    logger.log_to_file("Running command: " .. command, logger.LogLevel.DEBUG)
    logger.log_to_file("Command output: " .. (output or "nil"), logger.LogLevel.DEBUG)
    logger.log_to_file("Shell error: " .. vim.v.shell_error, logger.LogLevel.DEBUG)

    if vim.v.shell_error ~= 0 then
        logger.log_to_file("Failed to identify man page: " .. file .. " - Error: " .. vim.v.shell_error, logger.LogLevel.DEBUG)
        return false
    end

    if output and output:match("^%S+ %(%d%)") then
        logger.log_to_file("Confirmed man page: " .. file, logger.LogLevel.DEBUG)
        return true
    else
        logger.log_to_file("Not a man page: " .. file, logger.LogLevel.DEBUG)
        return false
    end
end

-- Improving decompression function to handle uncompressed files:
local function decompress_and_read(filepath)
    local command
    if filepath:match("%.gz$") then
        command = "gzip -dc '" .. filepath:gsub("'", "'\\''") .. "'"
    elseif filepath:match("%.bz2$") then
        command = "bzip2 -dc '" .. filepath:gsub("'", "'\\''") .. "'"
    elseif filepath:match("%.xz$") then
        command = "xz --decompress --stdout '" .. filepath:gsub("'", "'\\''") .. "'"
    else  -- Plain text or unsupported compressed format
        command = "cat '" .. filepath:gsub("'", "'\\''") .. "'"
    end

    local pipe, err = io.popen(command, 'r')
    if not pipe then
        logger.log_to_file("Failed to open pipe for: " .. filepath, logger.LogLevel.ERROR)
        return nil
    end
    local output = pipe:read("*all")
    pipe:close()
    if output and #output > 0 then
        return output
    else
        logger.log_to_file("No output or empty content after command execution: " .. filepath, logger.LogLevel.ERROR)
        return nil
    end
end

-- Parse man page content
local function advanced_parse_man_page(content)
    local cleaned_content = content:gsub("%.[A-Z]+", ""):gsub("\\f[IRB]", "")
    local title = content:match(".TH%s+\"([^\"]+)\"")
    local section = content:match(".SH%s+\"([^\"]+)\"")
    local synopsis = content:match(".SY%s+(.-)\n%.YS")
    local example = content:match(".EX(.-)\n%.EE")
    local hyperlink = content:match(".UR%s+(.-)\n%.UE")

    return {
        title = title,
        section = section,
        content = cleaned_content,
        synopsis = synopsis,
        example = example,
        hyperlink = hyperlink
    }
end

local function update_database_with_parsed_data(parsed_data, filepath, last_modified)
    if not config.config.database_path or config.config.database_path == "" then
        logger.log_to_file("Database path is not set or is empty", logger.LogLevel.ERROR)
        return
    end

    logger.log_to_file("Updating database with parsed data for file: " .. filepath, logger.LogLevel.DEBUG)

    local db = sqlite3.open(config.config.database_path)
    if not db then
        logger.log_to_file("Failed to open database at " .. config.config.database_path, logger.LogLevel.ERROR)
        return
    end

    local stmt = db:prepare([[
        REPLACE INTO man_pages (
            title, section, content, synopsis, example, hyperlink,
            file_path, last_modified, original_name, compressed_name, content_checksum
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]])
    if not stmt then
        logger.log_to_file("Failed to prepare SQL statement for: " .. filepath, logger.LogLevel.ERROR)
        db:close()
        return
    end

    local checksum = calculate_checksum(parsed_data.content)
    stmt:bind_values(
        parsed_data.title, parsed_data.section, parsed_data.content,
        parsed_data.synopsis, parsed_data.example, parsed_data.hyperlink,
        filepath, last_modified, parsed_data.original_name, parsed_data.compressed_name,
        checksum
    )
    local result = stmt:step()
    if result ~= sqlite3.DONE then
        logger.log_to_file("Failed to insert data into database for: " .. filepath, logger.LogLevel.ERROR)
    end
    stmt:finalize()
    db:close()
end

-- Process each man page file
local function process_file(fullpath, content)
    local attr = lfs.attributes(fullpath)
    local parsed_data = advanced_parse_man_page(content)
    logger.log_to_file("Processing file: " .. fullpath, logger.LogLevel.DEBUG)
    update_database_with_parsed_data(parsed_data, fullpath, attr.modification)
end

-- Process each directory containing man pages
local function process_directory(path)
    logger.log_to_file("Checking directory: " .. path, logger.LogLevel.DEBUG)
    for file in lfs.dir(path) do
        local fullpath = path .. '/' .. file
        logger.log_to_file("Inspecting file: " .. fullpath, logger.LogLevel.DEBUG)
        if file ~= "." and file ~= ".." then
            local attr = lfs.attributes(fullpath)
            if attr and attr.mode == "file" then
                if is_valid_man_page(fullpath) then
                    local content = decompress_and_read(fullpath)
                    if content then
                        process_file(fullpath, content)
                    else
                        logger.log_to_file("Failed to read or decompress file: " .. fullpath, logger.LogLevel.ERROR)
                    end
                else
                    logger.log_to_file("Skipped non-manpage file: " .. fullpath, logger.LogLevel.DEBUG)
                end
            end
        end
    end
end

-- Main processing function
local function main()
    logger.log_to_file("Starting directory processing", logger.LogLevel.INFO)
    local man_directories = get_man_directories()
    for _, path in ipairs(man_directories) do
        if directory_exists(path) then
            logger.log_to_file("Processing directory: " .. path, logger.LogLevel.DEBUG)
            process_directory(path)
        else
            logger.log_to_file("Directory does not exist or cannot be accessed: " .. path, logger.LogLevel.WARNING)
        end
    end
end

main()
