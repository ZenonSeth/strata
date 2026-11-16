local TEXT_COLOR = "#101010"
local TEXT_SIZE = 16
local COLUMNS = 2
local ROW_H = 1.8
local NAME_H = 0.42
local ICON = 0.9
local MAX_NAMES = 2
local SCROLLBAR_W = 0.4
local PAD = 0.3
local SCROLL_NAME = "discoveries_scroll"

local SUBTABS = {
	{id = "ores", title = "Ores", kinds = {ore = true, liquid = true}},
	{id = "materials", title = "Materials", kinds = {smelted = true}},
	{id = "gems", title = "Gems", kinds = {gem = true}},
	{id = "misc", title = "Misc", kinds = {relic = true}, hidden_until_found = true},
}

local function matching(tab)
	local list = {}
	for i, def in ipairs(str_materials.list) do
		if tab.kinds[def.kind] then
			list[#list + 1] = {def = def, order = i}
		end
	end
	return list
end

local function found_items(player, tab)
	local all = matching(tab)
	local found = {}
	for _, entry in ipairs(all) do
		if str_recipes.has_found(player, entry.def.name) then
			found[#found + 1] = entry
		end
	end
	table.sort(found, function(a, b)
		if a.def.price ~= b.def.price then
			return a.def.price < b.def.price
		end
		return a.order < b.order
	end)
	return found, #all
end

local function display_name(def)
	local number = def.kind == "relic" and def.name:match("%d+")
	return number and (def.description .. " " .. number) or def.description
end

-- What a material is for, worked out from the fuel, smelter and upgrade data so it cannot go stale
local uses
local function build_uses()
	uses = {}
	for _, def in ipairs(str_materials.list) do
		uses[def.name] = {fuel = str_materials.fuel[def.name] ~= nil, smelts = {}, upgrades = false, crafts = false}
	end
	for _, def in ipairs(str_materials.list) do
		if def.kind == "smelted" then
			for input in pairs(def.from) do
				table.insert(uses[input].smelts, def.description)
			end
		end
	end
	for _, category in ipairs(str_machine_data.upgrades) do
		for _, level in ipairs(category.levels) do
			for input in pairs(level.from or {}) do
				uses[input].upgrades = true
			end
		end
	end
	for _, craftable in ipairs(str_upgrades.craftables) do
		for input in pairs(craftable.from or {}) do
			uses[input].crafts = true
		end
	end
end

local function note(def)
	if not uses then
		build_uses()
	end
	local use = uses[def.name]
	local parts = {}
	if use.fuel then
		parts[#parts + 1] = "Fuel for smelting."
	end
	if #use.smelts > 0 then
		table.sort(use.smelts)
		local names = {}
		for i = 1, math.min(MAX_NAMES, #use.smelts) do
			names[i] = use.smelts[i]
		end
		parts[#parts + 1] = "Smelts into " .. table.concat(names, ", ") .. (#use.smelts > MAX_NAMES and " and more." or ".")
	end
	if use.upgrades and use.crafts then
		parts[#parts + 1] = "Used for upgrades and workbench items."
	elseif use.upgrades then
		parts[#parts + 1] = "Used for upgrades."
	elseif use.crafts then
		parts[#parts + 1] = "Used for workbench items."
	end
	if #parts == 0 and def.kind ~= "relic" then
		parts[1] = "Sold for credits."
	end
	return table.concat(parts, " ")
end

local function visible_tabs(player)
	local tabs = {}
	for _, tab in ipairs(SUBTABS) do
		if not tab.hidden_until_found or #found_items(player, tab) > 0 then
			tabs[#tabs + 1] = tab
		end
	end
	return tabs
end

local function render(player, sub, area)
	local tab
	for _, candidate in ipairs(SUBTABS) do
		if candidate.id == sub then
			tab = candidate
		end
	end
	local items, total = found_items(player, tab)
	local esc = core.formspec_escape
	local fs = {}
	if not tab.hidden_until_found then
		fs[1] = ("hypertext[%g,%g;%g,0.7;count;<global color=%s size=%d><b>Found %d / %d</b>]"):format(
			area.x + PAD, area.y + 0.2, area.w - 2 * PAD, TEXT_COLOR, TEXT_SIZE, #items, total)
	end
	local view_y = area.y + 0.9
	local view_h = area.h - 0.9 - PAD
	local view_w = area.w - 2 * PAD - SCROLLBAR_W
	local col_w = view_w / COLUMNS
	local rows = math.ceil(#items / COLUMNS)
	local content_h = rows * ROW_H
	fs[#fs + 1] = ("scroll_container[%g,%g;%g,%g;%s;vertical;0.1]"):format(
		area.x + PAD, view_y, view_w, view_h, SCROLL_NAME)
	for i, entry in ipairs(items) do
		local x = ((i - 1) % COLUMNS) * col_w
		local y = math.floor((i - 1) / COLUMNS) * ROW_H
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(x, y + 0.1, ICON, ICON, esc(entry.def.icon))
		-- Separate elements: a newline in hypertext starts a paragraph with a fixed 10px gap
		local text_x, text_w = x + ICON + 0.3, col_w - ICON - 0.5
		fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;name_%d;<global margin=0 color=%s size=%d><b>%s</b>]"):format(
			text_x, y + 0.1, text_w, NAME_H + 0.1, i, TEXT_COLOR, TEXT_SIZE, esc(display_name(entry.def)))
		fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;item_%d;<global margin=0 color=%s size=%d>%s]"):format(
			text_x, y + 0.1 + NAME_H, text_w, ROW_H - 0.1 - NAME_H, i, TEXT_COLOR, TEXT_SIZE, esc(note(entry.def)))
	end
	fs[#fs + 1] = "scroll_container_end[]"
	if content_h > view_h then
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=10;largestep=50]"):format(
			math.ceil((content_h - view_h) * 10))
		fs[#fs + 1] = ("scrollbar[%g,%g;%g,%g;vertical;%s;0]"):format(
			area.x + area.w - PAD - SCROLLBAR_W, view_y, SCROLLBAR_W, view_h, SCROLL_NAME)
	end
	return table.concat(fs)
end

str_manual.register_dynamic_page("discoveries", "Discoveries", {
	subtabs = visible_tabs,
	render = render,
})
