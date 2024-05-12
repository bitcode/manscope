local lfs = require('lfs')
local sqlite3 = require('lsqlite3')
local config = require('manscope.config')
local logger = require('manscope.log_module')  -- Include the logging module

local function get_man_directories_from_env()
    local manpath = os.getenv("MANPATH")
    if manpath and #manpath > 0 then
        return vim.split(manpath, ':', true)
    else
        return {}
    end
end

local function get_man_directories_from_config()
    local paths = {}
    local file = io.open("/etc/manpath.config", "r")
    if file then
        for line in file:lines() do
            local path = line:match("^MANDATORY_MANPATH%s+(.+)$")
            if path then
                table.insert(paths, path)
            end
        end
        file:close()
    end
    return paths
end

local function get_man_directories()
    local paths = get_man_directories_from_env()
    for _, path in ipairs(get_man_directories_from_config()) do
        table.insert(paths, path)
    end
    return paths
end

local function calculate_checksum(input)
    local checksum = 0
    for i = 1, #input do
        checksum = (checksum + string.byte(input, i)) % 65536 -- Use a larger mod to reduce collisions
    end
    return checksum
end

local function decompress_and_read(filepath)
    local command
    if filepath:match("%.gz$") then
        command = "gzip -dc '" .. filepath .. "'"
    elseif filepath:match("%.bz2$") then
        command = "bzip2 -dc '" .. filepath .. "'"
    elseif filepath:match("%.xz$") then
        command = "xz --decompress --stdout '" .. filepath .. "'"
    elseif filepath:match("%.Z$") then
        command = "uncompress -c '" .. filepath .. "'"
    else
        return nil  -- Unsupported format or plain text file
    end

    local pipe = io.popen(command)
    if not pipe then
        logger.log_to_file("Failed to decompress file: " .. filepath, logger.LogLevel.ERROR)
        return nil
    end
    local output = pipe:read("*all")
    pipe:close()
    return output
end

local function advanced_parse_man_page(content)
    local cleaned_content = content:gsub("%.[A-Z]+", ""):gsub("\\f[IRB]", "") -- Remove standalone groff commands and font formatting
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
    logger.log_to_file("Database path: " .. config.database_path, logger.LogLevel.DEBUG)
    local db = sqlite3.open(config.database_path)
    local stmt = db:prepare([[
        REPLACE INTO man_pages (
            title, section, content, synopsis, example, hyperlink,
            file_path, last_modified, original_name, compressed_name, content_checksum
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]])
    if not stmt then
        logger.log_to_file("Failed to prepare SQL statement for: " .. filepath, logger.LogLevel.ERROR)
        return
    end

    local checksum = calculate_checksum(parsed_data.content)
    stmt:bind_values(
        parsed_data.title, parsed_data.section, parsed_data.content,
        parsed_data.synopsis, parsed_data.example, parsed_data.hyperlink,
        filepath, last_modified, parsed_data.original_name, parsed_data.compressed_name,
        checksum  -- Use the checksum calculated
    )
    local result = stmt:step()
    if result ~= sqlite3.DONE then
        logger.log_to_file("Failed to insert data into database for: " .. filepath, logger.LogLevel.ERROR)
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

local function process_directory(path)
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local fullpath = path .. '/' .. file
            local attr = lfs.attributes(fullpath)
            if attr and attr.mode == "directory" then
                process_directory(fullpath)
            elseif attr and attr.mode == "file" then
                if fullpath:match("%.[1-9]$") -- Standard man pages
                   or fullpath:match("%.[1-9]%.gz$") -- Gzipped man pages
                   or fullpath:match("%.[1-9]%.bz2$") -- Bzipped man pages
                   or fullpath:match("%.[1-9]%.xz$") then -- Xzipped man pages
                    local content = decompress_and_read(fullpath)
                    if content then
                        process_file(fullpath, content)
                    else
                        logger.log_to_file("Failed to read or decompress file: " .. fullpath, logger.LogLevel.ERROR)
                    end
                end
            end
        end
    end
end

local function main()
    logger.log_to_file("Starting directory processing", logger.LogLevel.INFO)
    local man_directories = get_man_directories()
    for _, path in ipairs(man_directories) do
        process_directory(path)
    end
end

main()
