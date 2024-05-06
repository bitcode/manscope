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
    local commands = vim.tbl_map(function(path)
        return "find " .. path .. " -type f -name '*.[0-9]*'"
    end, paths)
    local command = table.concat(commands, " || ")  -- Continue even if one find fails

    command = command .. " | sed 's/.*\\///' | sort -u"  -- Unique sorting of man page names
    local man_pages = vim.fn.systemlist(command)
    if vim.v.shell_error ~= 0 then
        log_to_file("Failed to list man pages using MANPATH: " .. vim.inspect(man_pages))
        return {}
    end
    return man_pages
end

local function search_man_pages(opts)
    log_to_file("Starting search...")
    local query = vim.fn.input("Search term: ")
    log_to_file("Search term: " .. query)

    local man_pages = get_all_man_pages()  -- Fetch all man pages using the new function
    local results = {}

    -- Using rg to search within man pages for the query
    for _, man_page in ipairs(man_pages) do
        local man_cmd = "man " .. man_page .. " | col -b | rg --context 5 -e '" .. query .. "'"
        local match_output = vim.fn.system(man_cmd)
        if vim.v.shell_error == 0 and not vim.trim(match_output) == "" then
            for _, line in ipairs(vim.split(match_output, '\n')) do
                table.insert(results, man_page .. ": " .. line)
            end
        end
        log_to_file("Processed man page: " .. man_page)
    end

    if #results == 0 then
        log_to_file("No detailed entries found for: " .. query)
        return
    end

    -- Display results using Telescope
    pickers.new(opts, {
        prompt_title = "Man pages for " .. query,
        finder = finders.new_table({
            results = results,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry,
                    ordinal = entry,
                }
            end
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if selection then
                    -- Open man page or perform other actions
                    vim.cmd('Man ' .. vim.fn.fnamemodify(selection.value, ':t'))
                    log_to_file("Selected value: " .. selection.value)
                end
                actions.close(prompt_bufnr)
            end)
            return true
        end
    }):find()
end
