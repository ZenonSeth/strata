local theme = str_gui.theme
local esc = core.formspec_escape

local HEADER_H = 0.7
local OPTIONS = "tableoptions[border=false;background=%s;highlight=%s;highlight_text=" .. theme.text .. "]"

-- A scrollable table under a fixed header row, in the shared look. spec fields:
--   x, y, w, h, name (the table's field name, read with core.explode_table_event)
--   columns = {{title = , spec = "text,width=12,padding=0.3"}, ...}
--   rows = {{cells = {text, ...}, color = optional row text color (default theme.text)}, ...}
--   selected = row index (0 = none)
-- Cells are escaped here. Returns the formspec elements.
function str_gui.list_table(spec)
	local specs, titles = {}, {}
	for i, col in ipairs(spec.columns) do
		specs[i] = col.spec
		titles[i] = esc(col.title)
	end
	local cells = {}
	for _, row in ipairs(spec.rows) do
		cells[#cells + 1] = row.color or theme.text
		for _, cell in ipairs(row.cells) do
			cells[#cells + 1] = esc(cell)
		end
	end
	return table.concat({
		OPTIONS:format("#2a2c30", "#2a2c30"),
		"tablecolumns[" .. table.concat(specs, ";") .. "]",
		("table[%g,%g;%g,%g;%s_header;%s;0]"):format(spec.x, spec.y, spec.w, HEADER_H, spec.name,
			table.concat(titles, ",")),
		OPTIONS:format("#1b1c1e", "#7a3f1d"),
		("tablecolumns[color,span=%d;%s]"):format(#spec.columns, table.concat(specs, ";")),
		("table[%g,%g;%g,%g;%s;%s;%d]"):format(spec.x, spec.y + HEADER_H, spec.w, spec.h - HEADER_H, spec.name,
			table.concat(cells, ","), spec.selected or 0),
	})
end
