local lfs = require('lfs')
local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')

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

local function get_man_directories()
    local paths = get_man_directories_from_env()
    for _, path in ipairs(get_man_directories_from_config()) do
        table.insert(paths, path)
        logger.log_to_file("Added to processing list: " .. path, logger.LogLevel.DEBUG)
    end
    return paths
end

local function calculate_checksum(input)
    local checksum = 0
    for i = 1, #input do
        checksum = (checksum + string.byte(input, i)) % 65536
    end
    return checksum
end

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
        logger.log_to_file("Failed to open pipe for: " .. filepath .. " with error: " .. err, logger.LogLevel.ERROR)
        return nil, err
    end
    local output = pipe:read("*all")
    local close_success = pipe:close()
    if not close_success then
        logger.log_to_file("Failed to close pipe for: " .. filepath, logger.LogLevel.ERROR)
    end
    if output and #output > 0 then
        return output
    else
        logger.log_to_file("No output or empty content after command execution: " .. filepath, logger.LogLevel.ERROR)
        return nil
    end
end

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
        logger.log_to_file("Failed to open database at " .. config.config.database_path .. " with error: " .. (db and db:errmsg() or "unknown error"), logger.LogLevel.ERROR)
        return
    end

    local stmt = db:prepare([[
        REPLACE INTO man_pages (
            title, section, description, content, version, author, format,
            language, file_path, environment
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]])
    if not stmt then
        logger.log_to_file("Failed to prepare SQL statement for: " .. filepath .. " with error: " .. (db and db:errmsg() or "unknown error"), logger.LogLevel.ERROR)
        db:close()
        return
    end

    local title = parsed_data.title or ""
    local section = parsed_data.section or ""
    local description = parsed_data.synopsis or ""
    local content = parsed_data.content or ""
    local version = parsed_data.version or ""
    local author = parsed_data.author or ""
    local format = parsed_data.format or ""
    local language = parsed_data.language or ""
    local environment = parsed_data.environment or ""

    stmt:bind_values(
        title, section, description,
        content, version, author, format,
        language, filepath, environment
    )
    
    local values = {title, section, description, content, version, author, format, language, filepath, environment}
    logger.log_to_file("Executing SQL: REPLACE INTO man_pages VALUES(" .. table.concat(values, ", ") .. ")", logger.LogLevel.DEBUG)
    
    local result = stmt:step()
    if result ~= sqlite3.DONE then
        logger.log_to_file("Failed to insert data into database for: " .. filepath .. " with error: " .. (stmt and stmt:errmsg() or "unknown error"), logger.LogLevel.ERROR)
    else
        logger.log_to_file("Successfully inserted data into database for: " .. filepath, logger.LogLevel.DEBUG)
    end
    stmt:finalize()
    db:close()
end

local function process_file(fullpath, content)
    local attr = lfs.attributes(fullpath)
    local parsed_data = advanced_parse_man_page(content)
    logger.log_to_file("Processing file: " .. fullpath, logger.LogLevel.DEBUG)
    update_database_with_parsed_data(parsed_data, fullpath, attr.modification)
end

local function is_valid_man_page(file)
    local command = "man --path " .. vim.fn.shellescape(file)
    local output = vim.fn.system(command)

    logger.log_to_file("Running command: " .. command, logger.LogLevel.DEBUG)
    logger.log_to_file("Command output: " .. (output or "nil"), logger.LogLevel.DEBUG)
    logger.log_to_file("Shell error: " .. vim.v.shell_error, logger.LogLevel.DEBUG)

    if vim.v.shell_error ~= 0 then
        logger.log_to_file("Failed to identify man page: " .. file .. " - Error: " .. vim.v.shell_error, logger.LogLevel.ERROR)
        return false
    end
    return true
end

local function process_directory(path)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local fullpath = path .. '/' .. file
            local mode = lfs.attributes(fullpath, "mode")
            if mode == "directory" then
                process_directory(fullpath)
            elseif mode == "file" then
                if is_valid_man_page(fullpath) then
                    local content, err = decompress_and_read(fullpath)
                    if content then
                        process_file(fullpath, content)
                    else
                        logger.log_to_file("Failed to read or decompress file: " .. fullpath .. (err and (" with error: " .. err) or ""), logger.LogLevel.ERROR)
                    end
                else
                    logger.log_to_file("Skipped non-manpage file: " .. fullpath, logger.LogLevel.DEBUG)
                end
            end
        end
    end
end

local uv = vim.loop

local function async_start_parsing()
    local man_directories = get_man_directories()

    local function process_path(path)
        if directory_exists(path) then
            logger.log_to_file("Processing directory: " .. path, logger.LogLevel.DEBUG)
            process_directory(path)
        else
            logger.log_to_file("Directory does not exist or cannot be accessed: " .. path, logger.LogLevel.WARNING)
        end
    end

    for _, path in ipairs(man_directories) do
        uv.new_thread(process_path, path)
    end
end

return {
    start_parsing = async_start_parsing
}
