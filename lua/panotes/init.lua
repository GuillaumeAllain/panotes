local api = vim.api
local scandir = require("plenary.scandir")
local _show_tags = require("telescope.builtin").tags
local m = {}

local function _change_cwd_to_notes_dir()
	vim.cmd("e" .. vim.fn.expand("$NOTES_DIR/") .. ".notes")
end

local function _opentemppandocbuff(loctable, opt)
	api.nvim_command("silent enew") -- equivalent to :enew
	api.nvim_buf_set_lines(buf, 0, -1, false, loctable)
	vim.bo[0].filetype = "pandoc"
	vim.bo[0].buftype = "nofile" -- set the current buffer's (buffer 0) buftype to nofile
	vim.bo[0].bufhidden = "delete"
	vim.bo[0].swapfile = false
	vim.bo[0].readonly = true
	vim.bo[0].modifiable = false
	vim.bo[0].buflisted = false
end

function _G.Panotes_tags(arglead, cmdline, cursorpos)
	local taglist_raw = vim.fn.taglist("/*", vim.fn.tagfiles()[1])
	local taglist_processed = {}
	for _, tag in ipairs(taglist_raw) do
		local append = true
		for _, previous_tags in ipairs(taglist_processed) do
			if tag.name == previous_tags then
				append = false
				break
			end
		end
		if append then
			taglist_processed[#taglist_processed + 1] = tag.name
		end
	end
	return api.nvim_call_function("join", { taglist_processed, "\n" })
end

local function _panotes_file_list(input_tag)
	local taglist_raw = vim.fn.taglist("/*", vim.fn.tagfiles()[1])
	local file_list = {}
	for _, tag in ipairs(taglist_raw) do
		local append = true
		for _, previous_tags in ipairs(file_list) do
			if tag.filename == previous_tags then
				append = false
				break
			end
		end
		if append and tag.name == input_tag then
			file_list[#file_list + 1] = tag.filename
		end
	end
	return file_list
end

local function _openTag(tag)
	local result = require("panotes.grep_utils").grep_file_list(_panotes_file_list(tag), tag)
	_opentemppandocbuff(result, {})
end

local function _get_filename_from_path(path)
	local _, filename, _ = string.match(path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	return filename
end

local function _get_datetime_from_journal_filename(path)
	local jyear, jmonth, jday = string.match(path, "(%d%d%d%d)(%d%d)(%d%d).md")
	return os.time({ year = jyear, day = jday, month = jmonth })
end

local function _opennewdiary(todayfile)
	local rfile = io.open(os.getenv("HOME") .. "/.local/share/pandot/templates/documents/diary.md", "r")
	local templatetable = {}
	local filename = vim.fn.system("id -F"):gsub("\n", "")
	local replacetable = {
		fullname = filename,
		diaryname = "Notes du " .. os.date("%Y-%m-%d"),
		date = os.date("%Y-%m-%d"),
		projectname = "journal",
		docstyle = "diary",
	}
	local locline = ""
	for line in rfile:lines() do
		locline = line
		for key, value in pairs(replacetable) do --actualcode
			locline = locline:gsub("{" .. key .. "}", value)
		end
		templatetable[#templatetable + 1] = locline
	end
	api.nvim_command("e " .. todayfile)
	api.nvim_buf_set_lines(buf, 0, -1, false, templatetable)
end

function m.openDiary()
	local todayfile = vim.fn.expand("$NOTES_DIR/journal" .. "/" .. os.date("%Y%m%d.md"))
	print(todayfile)
	if vim.fn.filereadable(todayfile) == 0 then
		_opennewdiary(todayfile)
	else
		api.nvim_command("e " .. todayfile)
	end
end

function m.openJournal()
	local output = scandir.scan_dir(vim.fn.expand("$NOTES_DIR/journal"))
	local datetime = ""
	local filename = ""
	local month = ""
	local datestring = ""
	local filetable = {}
	for _, value in ipairs(output) do
		filename = _get_filename_from_path(value)
		datetime = _get_datetime_from_journal_filename(filename)
		datestring = os.date("%B %Y", datetime):gsub("^%l", string.upper)
		if month ~= datestring then
			if month ~= "" then
				filetable[#filetable + 1] = " "
			end
			month = datestring
			filetable[#filetable + 1] = "# " .. month
			filetable[#filetable + 1] = " "
		end
		datestring = os.date("%A le %d", datetime)
		filetable[#filetable + 1] = datestring .. ":" .. string.rep(" ", 15 - #datestring) .. filename
	end
	_opentemppandocbuff(filetable, { directory = vim.fn.expand("$NOTES_DIR/journal") })
end

function m.openTagInput()
	_change_cwd_to_notes_dir()
	local taginput = vim.fn.input({ prompt = "Tag to search: ", completion = "custom,v:lua.Panotes_tags" })
	if taginput == nil then
		return
	end
	_openTag(taginput)
end

function m.searchTags()
	_change_cwd_to_notes_dir()
	_show_tags({ ctags_file = vim.fn.tagfiles()[1] })
end

-- function m.export_to_org()
-- 	api.nvim_command("w!")
-- 	local result = vim.fn.systemlist("panotes exporttodo")
-- 	api.nvim_command("e")
-- end

function _G.Panotes_complete(arglead, cmdline, cursorpos)
	return api.nvim_call_function(
		"join",
		{ { "openDiary", "openJournal", "openTagInput", "searchTags", "export_to_org" }, "\n" }
	)
end

function m.load_command(command)
	vim.cmd("lua require('panotes')." .. command .. "()")
end

local function make_commands()
	vim.cmd(
		[[command! -nargs=* -complete=custom,v:lua.Panotes_complete Panotes    lua require('panotes').load_command(<f-args>)]]
	)
end

function m.setup() end

make_commands()

return m
