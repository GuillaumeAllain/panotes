local M = {}

local function _get_pandoc_command(regex)
	local pandoc_command = {
		"/usr/local/bin/pandoc",
		"-M greppattern=" .. regex,
		"-M block_top=" .. 2,
		"-L "..pandoc_filters_path.."greppattern.lua ",
		"--shift-heading-level-by=1 ",
		"-t markdown+yaml_metadata_block-grid_tables-simple_tables-multiline_tables-latex_macros",
		"-L "..pandoc_filters_path.."math_spaces.lua ",
		"--markdown-headings=atx --wrap=preserve -V header-includes= -V include-before= -V include-after= ",
	}
	return vim.api.nvim_call_function("join", { pandoc_command, " " })
end

function M.grep_file(file, regex)
	local input = vim.api.nvim_call_function("join", { vim.fn.readfile(vim.fn.expand(file)), "\n" })
	local output = vim.fn.system(_get_pandoc_command(regex), input)
	return output
end

function M.clean_buffer_input(result)
	result = result:gsub('"(.*)"', "%1")
	result = result:gsub("\\n", "\n")
	result = result:gsub("\\r", "\r")
	local resulttable = {}
	for s in result:gmatch("[^\r\n]+") do
		resulttable[#resulttable + 1] = s
	end
	return resulttable
end

function M.grep_file_list(filelist, regex)
	local outtable = {}
	for _, file in ipairs(filelist) do
		outtable[#outtable + 1] = "# " .. file
		outtable[#outtable + 1] = M.grep_file(file, regex)
	end
	return M.clean_buffer_input(vim.api.nvim_call_function("join", { outtable, "\n" .. " \n" }))
end

return M
