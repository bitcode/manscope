local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

local function is_command_available(command)
    return vim.fn.executable(command) == 1
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
    if not is_command_available("apropos") or not is_command_available("man") or not is_command_available("rg") then
        print("Required command(s) not available. Please ensure 'apropos', 'man', and 'rg' are installed.")
        return
    end

    opts = opts or {}
    local query = vim.fn.input("Search term: ")
    local apropos_command = "apropos " .. query .. " | awk '{print $1}'"
    local man_pages = vim.fn.systemlist(apropos_command)

    if vim.v.shell_error ~= 0 or #man_pages == 0 then
        print("Error or no man pages found for: " .. query)
        return
    end

    -- Use a more efficient way to process each man page individually
    local results = {}
    for _, man_page in ipairs(vim.fn.systemlist("apropos . | awk '{print $1}'")) do
    local man_cmd = string.format("man %s | rg --context 5 '%s'", man_page, query)
    local page_results = vim.fn.systemlist(man_cmd)
    if vim.v.shell_error == 0 and #page_results > 0 then
        vim.list_extend(results, page_results)
    end
end

    if #results == 0 then
        print("No detailed entries found for: " .. query)
        return
    end

    pickers.new(opts, {
        prompt_title = "Man pages for " .. query,
        finder = finders.new_table({
            results = results,
            entry_maker = entry_maker  -- Use the customized entry maker
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                if selection then
                    print(selection.value)  -- or any other more specific action
                end
                actions.close(prompt_bufnr)
            end)
            return true
        end
    }):find()
end

return man_search
