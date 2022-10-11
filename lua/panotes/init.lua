local m = {}

function _G.Panotes_complete(arglead, cmdline, cursorpos)
	return vim.aapi.nvim_call_function(
		"join",
		{ { "openDiary", "openJournal", "openTagInput", "searchTags", "liveGrep" }, "\n" }
	)
end

local function make_commands()
	vim.cmd(
		[[command! -nargs=* -complete=custom,v:lua.Panotes_complete Panotes    lua require('panotes.commands').load_command(<f-args>)]]
	)
end

function m.setup()
	make_commands()
end

return m
