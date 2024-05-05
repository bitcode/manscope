local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function log_to_file(msg)
    local log_file = vim.fn.stdpath('cache') .. '/manscope.log'
    local date = os.date('%Y-%m-%d %H:%M:%S')
    local final_message = string.format("[%s] %s\n", date, msg)
    local file = io.open(log_file, 'a')
    if file then
        file:write(final_message)
        file:close()
    end
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

    -- Directly list all man pages and search
    local all_man_pages_command = "man -k . | awk '{print $1}'"
    local all_man_pages = vim.fn.systemlist(all_man_pages_command)
    local results = {}

    for _, man_page in ipairs(all_man_pages) do
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

return man_search

