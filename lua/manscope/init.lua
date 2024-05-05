local config = {
    context_lines = 5,  -- Default context lines for rg
    commands = {
        apropos = "apropos",
        man = "man",
        rg = "rg"
    }
}

M.setup = function(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end
