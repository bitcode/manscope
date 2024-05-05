local telescope = require('telescope')

return telescope.register_extension({
    exports = {
        manscope = require('manscope.man_search').search_man_pages,
    },
})
