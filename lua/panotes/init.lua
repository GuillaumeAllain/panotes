local m = {}

local function make_commands()
    vim.cmd(
        [[command! -nargs=* -complete=custom,v:lua.Panotes_complete Panotes    lua require('panotes.command').load_command(<f-args>)]]
    )
end

function m.setup() end

make_commands()

return m
