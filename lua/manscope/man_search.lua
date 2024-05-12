local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local logger = require('manscope.log_module')
local config = require('manscope.config')
local sqlite3 = require('lsqlite3')

local function search_man_pages(opts)
    logger.log_to_file("Starting search...")
    local query = vim.fn.input("Search term: ")
    logger.log_to_file("Search term: " .. query)

    local db = sqlite3.open(config.database_path)

    -- Enhanced search query that incorporates synonyms for more flexible searches
    local sql = string.format([[
        SELECT mp.title, mp.content, bm25(mp, 10.0, 1.0) AS rank
        FROM man_pages mp
        LEFT JOIN synonyms s ON mp.content MATCH s.synonym
        WHERE mp.title MATCH '%s' OR mp.content MATCH '%s' OR s.term = '%s'
        ORDER BY rank DESC  -- Order by descending rank for best matches first
    ]], query, query, query)

    local results = {}
    for row in db:nrows(sql) do
        table.insert(results, string.format("Title: %s, Content: %s, Rank: %f", row.title, row.content, row.rank))
    end
    db:close()

    if #results == 0 then
        logger.log_to_file("No entries found for: " .. query)
        print("No results found.")
        return
    end

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
                    logger.log_to_file("Selected value: " .. selection.value)
                    print("Selected: ", selection.value)
                end
                actions.close(prompt_bufnr)
            end)
            return true
        end
    }):find()
end

return {
    search_man_pages = search_man_pages
}
