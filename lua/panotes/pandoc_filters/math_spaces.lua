local function math_spaces(inlines)
	local out_inlines = {}
	local valid_inline = { t = "RawInline" }
	for _, inline in ipairs(inlines) do
		if inline.t == "RawInline" and inline.format == "tex" then
			out_inlines[#out_inlines + 1] = pandoc.RawInline("markdown", inline.text)
		else
			out_inlines[#out_inlines + 1] = inline
		end
	end
	return out_inlines
end

return { {
	Inlines = math_spaces,
} }
