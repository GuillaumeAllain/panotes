local api = vim.api
local scandir = require("plenary.scandir")
local m = {}

function m.change_cwd_to_notes_dir()
	vim.cmd("cd $NOTES_DIR/")
end

-- function _G.Panotes_tags(arglead, cmdline, cursorpos)
-- 	local taglist_raw = vim.fn.taglist("/*", vim.fn.tagfiles()[1])
-- 	local taglist_processed = {}
-- 	for _, tag in ipairs(taglist_raw) do
-- 		local append = true
-- 		local tag_name = tag.name:sub(2)
-- 		for _, previous_tags in ipairs(taglist_processed) do
-- 			if tag_name == previous_tags then
-- 				append = false
-- 				break
-- 			end
-- 		end
-- 		if append then
-- 			taglist_processed[#taglist_processed + 1] = tag_name
-- 		end
-- 	end
-- 	return api.nvim_call_function("join", { taglist_processed, "\n" })
-- end

function m.panotes_tags()
	local taglist_raw = vim.fn.taglist("/*", vim.fn.tagfiles()[1])
	local taglist_processed = {}
	for _, tag in ipairs(taglist_raw) do
		local append = true
		local tag_name = tag.name:sub(2)
		for _, previous_tags in ipairs(taglist_processed) do
			if tag_name == previous_tags then
				append = false
				break
			end
		end
		if append then
			taglist_processed[#taglist_processed + 1] = tag_name
		end
	end
	-- return api.nvim_call_function("join", { taglist_processed, "\n" })
	return taglist_processed
end

function _G.Panotes_folders_complete(arglead, _, _)
	local output = {}
	local current_dir = vim.fn.resolve(vim.fn.expand("$NOTES_DIR/"))
	local current_dir_arg = vim.fn.resolve(vim.fn.expand("$NOTES_DIR/" .. arglead))
	if vim.fn.isdirectory(current_dir_arg) == 1 then
		output = scandir.scan_dir(current_dir_arg, { add_dirs = true, depth = 1 })
		for index, _ in ipairs(output) do
			output[index] = arglead .. (string.gsub(output[index], current_dir_arg .. "/", ""))
		end
	elseif vim.fn.isdirectory(current_dir) == 1 then
		local input = scandir.scan_dir(current_dir, { add_dirs = true, depth = 1 })
		for index, _ in ipairs(input) do
			input[index] = (string.gsub(input[index], current_dir .. "/", ""))
			if input[index]:find(arglead) then
				output[#output + 1] = input[index]
			end
		end
	end
	return api.nvim_call_function("join", { output, "\n" })
end

local function _opentemppandocbuff(loctable)
	api.nvim_command("silent enew")
	api.nvim_buf_set_lines(0, 0, -1, false, loctable)
	vim.bo[0].filetype = "pandoc"
	vim.bo[0].buftype = "nofile"
	vim.bo[0].bufhidden = "delete"
	vim.bo[0].swapfile = false
	vim.bo[0].readonly = true
	vim.bo[0].modifiable = false
	vim.bo[0].buflisted = false
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

local function _get_filename_from_path(path)
	local _, filename, _ = string.match(path, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	return filename
end

local function _get_datetime_from_journal_filename(path)
	local jyear, jmonth, jday = string.match(path, "(%d%d%d%d)(%d%d)(%d%d).md")
	return os.time({ year = jyear, day = jday, month = jmonth })
end

local function _newdiary_content()
	local rfile = {
		"---",
		"author: {fullname}",
		"title: {diaryname}",
		"subtitle: {projectname}",
		"date: {date}",
		"docstyle: diary",
		"---",
	}
	local templatetable = {}
	local filename = vim.fn.system("id -F"):gsub("\n", "")
	local habits = vim.fn.systemlist("habits --no-cal --list")
	local replacetable = {
		fullname = filename,
		diaryname = "Notes du " .. os.date("%Y-%m-%d"),
		date = os.date("%Y-%m-%d"),
		projectname = "journal",
		docstyle = "diary",
	}
	local locline = ""
	for _, line in ipairs(rfile) do
		locline = line
		for key, value in pairs(replacetable) do --actualcode
			locline = locline:gsub("{" .. key .. "}", value)
		end
		templatetable[#templatetable + 1] = locline
	end
	templatetable[#templatetable + 1] = ""
	templatetable[#templatetable + 1] = "# Habitudes"
	for _, line in ipairs(habits) do
		templatetable[#templatetable + 1] = line
	end
	return templatetable
end

local function _todayfile()
	return vim.fn.expand("$NOTES_DIR/journal" .. "/" .. os.date("%Y%m%d.md"))
end

local function _open_file_buffer(filename)
	local buffer_number = nil
	local buffer_list = vim.fn.getbufinfo()
	local already_open = false

	for k in pairs(buffer_list) do
		if
			vim.fn.fnamemodify(vim.fn.bufname(buffer_list[k].bufnr), ":p") == vim.fn.resolve(vim.fn.expand(filename))
		then
			buffer_number = vim.fn.deepcopy(buffer_list[k].bufnr)
			already_open = true
			break
		end
	end

	if not already_open then
		buffer_number = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buffer_number, vim.fn.fnameescape(vim.fn.expand(filename)))
		vim.api.nvim_set_option_value("filetype", "pandoc", { buf = buffer_number })
		if vim.fn.filereadable(filename) == 1 then
			vim.api.nvim_buf_call(buffer_number, function()
				vim.cmd("silent exec ':e|w!'")
			end)
		end
	end
	return { number = buffer_number, state = already_open }
end

local function _open_diary_buffer()
	local template_flag = false
	local todayfile = _todayfile()
	if vim.fn.filereadable(todayfile) == 0 then
		template_flag = true
	end
	local buffer_info = _open_file_buffer(todayfile)
	if template_flag then
		vim.api.nvim_buf_set_lines(buffer_info.number, 0, -1, false, _newdiary_content())
	end
	return buffer_info
end

function m.openDiary()
	local buffer_info = _open_diary_buffer()
	vim.api.nvim_exec2("buffer " .. buffer_info.number, {})
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
		if string.match(filename, "^%d%d%d%d%d%d%d%d.md$") then
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
			filetable[#filetable + 1] = datestring .. string.rep(" ", 15 - #datestring) .. "journal/" .. filename
		end
	end
	m.change_cwd_to_notes_dir()
	-- _opentemppandocbuff(filetable, { directory = vim.fn.expand("$NOTES_DIR/journal") })
	_opentemppandocbuff(filetable)
end

local function _openTag(tag)
	vim.cmd("nos e " .. vim.fn.expand("$NOTES_DIR/.notes"))
	local result = require("panotes.grep_utils").grep_file_list(_panotes_file_list(tag), tag)
	vim.api.nvim_set_option_value("buflisted", false, { buf = vim.fn.bufnr() })
	_opentemppandocbuff(result, _)
end

function m.openTagInput()
	local altfile = vim.fn.getreg("#")

	vim.cmd("nos e " .. vim.fn.expand("$NOTES_DIR/.notes"))
	local tags = m.panotes_tags()
	vim.api.nvim_set_option_value("buflisted", false, { buf = vim.fn.bufnr() })
	vim.cmd("bd!")
	if altfile ~= "" then
		vim.fn.setreg("#", altfile)
	else
		vim.cmd([["let @# = ''"]])
	end

	vim.ui.select(tags, {
		prompt = "Tag to search: ",
	}, function(choice)
		local taginput = choice
		if taginput == nil then
			return
		end
		taginput = "#" .. taginput
		_openTag(taginput)
	end)
end

function m.liveGrep()
	local altfile = vim.fn.getreg("%")
	vim.cmd("e " .. vim.fn.expand("$NOTES_DIR/") .. ".notes")
	require("telescope.builtin").live_grep({
		ctags_file = vim.fn.tagfiles()[1],
		attach_mappings = function(_)
			require("telescope.actions.set").select:enhance({
				post = function()
					if vim.api.nvim_buf_get_name(0) ~= "" then
						vim.cmd("silent! bw " .. vim.fn.fnameescape(vim.fn.resolve(vim.fn.expand("$NOTES_DIR/.notes"))))
					end
				end,
			})
			require("telescope.actions").close:enhance({
				post = function()
					if vim.api.nvim_buf_get_name(0) ~= "" then
						vim.cmd("silent! bw " .. vim.fn.fnameescape(vim.fn.resolve(vim.fn.expand("$NOTES_DIR/.notes"))))
					end
				end,
			})
			return true
		end,
	})
	if altfile ~= "" then
		vim.fn.setreg("#", altfile)
	end
end

function m.searchTags()
	local altfile = vim.fn.getreg("%")
	vim.cmd("e " .. vim.fn.expand("$NOTES_DIR/") .. ".notes")
	require("telescope.builtin").tags({
		ctags_file = vim.fn.tagfiles()[1],
		attach_mappings = function(_)
			require("telescope.actions.set").select:enhance({
				post = function()
					if vim.api.nvim_buf_get_name(0) ~= "" then
						vim.cmd("silent! bw " .. vim.fn.fnameescape(vim.fn.resolve(vim.fn.expand("$NOTES_DIR/.notes"))))
					end
				end,
			})
			require("telescope.actions").close:enhance({
				post = function()
					if vim.api.nvim_buf_get_name(0) ~= "" then
						vim.cmd("silent! bw " .. vim.fn.fnameescape(vim.fn.resolve(vim.fn.expand("$NOTES_DIR/.notes"))))
					end
				end,
			})
			return true
		end,
	})
	if altfile ~= "" then
		vim.fn.setreg("#", altfile)
	end
end

function m.get_capture_buffer()
	-- Returns build terminal handle. If not found, it creates it
	local buffer_list = vim.fn.getbufinfo()
	local create_buffer = true
	local buffer_number = nil

	for k in pairs(buffer_list) do
		if vim.fn.bufname(buffer_list[k].bufnr) == "panotes://Capture" then
			buffer_number = vim.fn.deepcopy(buffer_list[k].bufnr)
			create_buffer = false
			break
		end
	end

	if create_buffer then
		buffer_number = vim.api.nvim_create_buf(false, true)

		-- Set the buffer type to "prompt" to give it special behaviour (:h prompt-buffer)
		vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer_number })
		vim.api.nvim_set_option_value("ft", "pandoc", { buf = buffer_number })
		vim.api.nvim_buf_set_name(buffer_number, "panotes://Capture")
	end

	return buffer_number
end

function m.get_capturename_buffer()
	-- Returns build terminal handle. If not found, it creates it
	local buffer_list = vim.fn.getbufinfo()
	local create_buffer = true
	local buffer_number = nil

	for k in pairs(buffer_list) do
		if vim.fn.bufname(buffer_list[k].bufnr) == "panotes://CaptureName" then
			buffer_number = vim.fn.deepcopy(buffer_list[k].bufnr)
			create_buffer = false
			break
		end
	end

	if create_buffer then
		buffer_number = vim.api.nvim_create_buf(false, false)

		-- Set the buffer type to "prompt" to give it special behaviour (:h prompt-buffer)

		vim.api.nvim_set_option_value("buftype", "nofile", { buf = buffer_number })
		vim.api.nvim_buf_set_name(buffer_number, "panotes://CaptureName")
		vim.api.nvim_buf_set_lines(buffer_number, 0, -1, false, { "  Panotes Capture " })
	end

	return buffer_number
end

local function _append_to_buffer(buffer_info, lines)
	vim.api.nvim_buf_set_lines(buffer_info.number, -1, -1, false, lines)
	vim.api.nvim_buf_call(buffer_info.number, function()
		vim.cmd("silent exec 'w'")
	end)
	if not buffer_info.state then
		vim.api.nvim_buf_delete(buffer_info.number, {})
	end
end

function m.close_capture(buf, _)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	table.insert(lines, 1, "")
	-- vim.api.nvim_buf_delete(bufname, {})
	vim.cmd([[
        augroup PanotesCapture
        au!
        augroup END
        ]])
	local file_decision = vim.fn.input({
		prompt = "Where to save?:\n\t (1) Append to diary\n\t (2) Append to note\n\t (3) Discard \n:",
	})
	vim.api.nvim_command("redraw")
	if file_decision == "1" then
		local buffer_info = _open_diary_buffer()
		_append_to_buffer(buffer_info, lines)
	elseif file_decision == "2" then
		local filename = vim.fn.input({
			prompt = "Filename?:\n:",
			completion = "custom,v:lua.Panotes_folders_complete",
		})
		vim.api.nvim_command("redraw")
		local buffer_info = _open_file_buffer(vim.fn.expand("$NOTES_DIR/") .. filename)
		_append_to_buffer(buffer_info, lines)
	end
	vim.api.nvim_buf_delete(buf, {})
	vim.api.nvim_command("redraw")
end

function m.capture()
	local window_config = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = vim.fn.ceil(vim.o.columns / 2),
		height = vim.fn.ceil(vim.o.lines / 10),
		col = vim.fn.ceil((vim.o.columns / 2) - (vim.o.columns / 4)) + vim.o.cmdheight,
		row = vim.fn.ceil((vim.o.lines / 2) - (vim.o.lines / 20)),
		title = "Panotes Capture",
		title_pos = "center",
	}
	-- local window_name_config = {
	--     relative = "editor",
	--     style = "minimal",
	--     width = 9,
	--     height = 1,
	--     col = window_config.col + 2,
	--     row = window_config.row,
	--     zindex = 100,
	-- }

	local buf = m.get_capture_buffer()
	-- local bufname = m.get_capturename_buffer()
	vim.api.nvim_open_win(buf, true, window_config)
	-- local window_name_name = vim.api.nvim_open_win(bufname, false, window_name_config)
	vim.cmd([[augroup panotescapture
	    au!
	autocmd WinClosed,BufDelete,WinLeave <buffer=]] .. buf .. "> ++once lua require'panotes.commands'.close_capture(" .. buf .. [[)
        augroup END]])
end

function m.load_command(command)
	vim.cmd("lua require('panotes.commands')." .. command .. "()")
end

return m
