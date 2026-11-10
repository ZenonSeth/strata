local esc = core.formspec_escape
local format_credits = st_player_resources.format_credits

-- Header and body tables share these columns (min widths in em; about 37 em in all, which fits the smallest window)
local COLUMNS = {
	{title = "Item", spec = "text,width=14,padding=0.3"},
	{title = "Units", spec = "text,width=5,padding=0.3,tooltip=Units held"},
	{title = "Weight", spec = "text,width=6,padding=0.3,tooltip=Total weight (units x weight per unit)"},
	{title = "Price", spec = "text,width=8,padding=0.3,tooltip=Total price in credits"},
}
local ICON_COLUMN = "image,align=center,padding=0.3,width=2"
local HEADER_H = 0.7
local TABLE_OPTIONS = "tableoptions[border=false;background=%s;highlight=%s;highlight_text=" .. st_gui.theme.text .. "]"

-- One decimal, no trailing zero
function st_inventory.num(value)
	return ("%g"):format(math.floor(value * 10 + 0.5) / 10)
end

-- Rows for a name -> count table, most valuable per unit first; row index matches the table
function st_inventory.rows(contents)
	local list = {}
	for name, count in pairs(contents) do
		local def = st_materials.get(name)
		if def then
			list[#list + 1] = {def = def, count = count}
		end
	end
	table.sort(list, function(a, b)
		if a.def.price ~= b.def.price then
			return a.def.price > b.def.price
		end
		return a.def.name < b.def.name
	end)
	return list
end

function st_inventory.cargo_rows(player)
	return st_inventory.rows(st_machine.cargo.get(player))
end

local function columns(images)
	local specs = {ICON_COLUMN .. (images or "")}
	for i, col in ipairs(COLUMNS) do
		specs[i + 1] = col.spec
	end
	return "tablecolumns[" .. table.concat(specs, ";") .. "]"
end

local function header_table(spec)
	local cells = {""}
	for i, col in ipairs(COLUMNS) do
		cells[i + 1] = col.title
	end
	return table.concat({
		TABLE_OPTIONS:format("#2a2c30", "#2a2c30"),
		columns(),
		("table[%g,%g;%g,%g;%s_header;%s;0]"):format(spec.x, spec.y, spec.w, HEADER_H, spec.name or "items", table.concat(cells, ",")),
	})
end

-- Items as a scrollable table with a fixed header row (the header only shows when there are rows).
-- spec: x, y, w, h, name (table field name), selected (item name or nil), empty (text when empty).
-- Returns the formspec elements, the rows (st_inventory.rows) and the selected row index (0 = none).
function st_inventory.item_table(contents, spec)
	local list = st_inventory.rows(contents)
	local images, cells = {}, {}
	local selected = 0
	for i, row in ipairs(list) do
		local def = row.def
		images[i] = "," .. i .. "=" .. esc(def.icon)
		cells[#cells + 1] = tostring(i)
		cells[#cells + 1] = esc(def.description)
		cells[#cells + 1] = tostring(row.count)
		cells[#cells + 1] = st_inventory.num(row.count * def.weight)
		cells[#cells + 1] = format_credits(row.count * def.price)
		if def.name == spec.selected then
			selected = i
		end
	end
	local fs = {}
	local body_y, body_h = spec.y, spec.h
	if #list > 0 then
		fs[#fs + 1] = header_table(spec)
		body_y, body_h = spec.y + HEADER_H, spec.h - HEADER_H
	end
	fs[#fs + 1] = TABLE_OPTIONS:format("#1b1c1e", "#7a3f1d")
	fs[#fs + 1] = columns(table.concat(images))
	fs[#fs + 1] = ("table[%g,%g;%g,%g;%s;%s;%d]"):format(spec.x, body_y, spec.w, body_h,
		spec.name or "items", table.concat(cells, ","), selected)
	if #list == 0 then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(spec.x + 0.3, spec.y + 0.5, esc(spec.empty or "The hold is empty."))
	end
	return table.concat(fs), list, selected
end

-- The player's cargo; same as item_table
function st_inventory.cargo_table(player, spec)
	return st_inventory.item_table(st_machine.cargo.get(player), spec)
end
