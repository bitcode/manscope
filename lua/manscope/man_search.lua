local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function log_to_file(msg)
    local log_file_path = vim.fn.stdpath('cache') .. '/manscope.log'
    local date = os.date('%Y-%m-%d %H:%M:%S')
    local final_message = string.format("[%s] %s\n", date, msg)

    local file, err = io.open(log_file_path, 'a')
    if not file then
        print("Failed to open log file: " .. err)  -- Display error in Neovim
        return
    end

    file:write(final_message)
    file:close()
end

local function get_all_man_pages()
    local manpath = vim.fn.getenv("MANPATH")
    if manpath == vim.NIL or manpath == "" then
        manpath = "/usr/share/man:/usr/local/man"  -- Fallback if MANPATH isn't set
    end

    local paths = vim.split(manpath, ':', true)
    -- Use table.concat and vim.tbl_map to build the command
    local command = table.concat(vim.tbl_map(function(path)
        return "find " .. path .. " -type f -name '*.[0-9]*'"
    end, paths), "; ")  -- Using semicolon to separate commands

    command = command .. " | sed 's/.*\\///' | sort -u"
    local man_pages = vim.fn.systemlist(command)
    if vim.v.shell_error ~= 0 then
        log_to_file("Failed to list man pages using MANPATH.")
        return {}
    end
    return man_pages
end

local function is_command_available(command)
    if vim.fn.executable(command) == 0 then
        log_to_file("Command not found: " .. command)
        return false
    end
    return true
end

local man_search = {}

local entry_maker = function(entry)
    local parts = vim.split(entry, ':', true)
    local filename = parts[1]
    local line_number = parts[2]
    local content = table.concat(vim.list_slice(parts, 3), ':')
    local display_text = string.format("%s [%s]: %s", vim.fn.fnamemodify(filename, ":t"), line_number, content)
    return {
        value = entry,
        display = display_text,
        ordinal = content,
    }
end

man_search.search_man_pages = function(opts)
    log_to_file("Starting search...")
    if not is_command_available("man") or not is_command_available("rg") then
        log_to_file("Required command(s) not available. Please ensure 'man' and 'rg' are installed.")
        return
    end

    opts = opts or {}
    local query = vim.fn.input("Search term: ")
    log_to_file("Search term: " .. query)

    local man_pages = get_all_man_pages()  -- Fetch all man pages using the new function
    local results = {}

    for _, man_page in ipairs(man_pages) do
        local man_cmd = string.format("man %s | rg --context 5 '%s'", man_page, query)
        local page_results = vim.fn.systemlist(man_cmd)
        log_to_file("Processing man page: " .. man_page .. " with results count: " .. #page_results)
        if vim.v.shell_error == 0 and #page_results > 0 then
            vim.list_extend(results, page_results)
        end
    end

    if #results == 0 then
        log_to_file("No detailed entries found for: " .. query)
        return
    end

    pickers.new(opts, {
        prompt_title = "Man pages for " .. query,
        finder = finders.new_table({
            results = results,
            entry_maker = entry_maker
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if selection then
                    log_to_file("Selected value: " .. selection.value)
                end
                actions.close(prompt_bufnr)
            end)
            return true
        end
    }):find()
end
