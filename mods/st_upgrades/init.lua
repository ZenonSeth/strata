st_upgrades = {}

local FORMNAME = "st_upgrades:main"

local WIDTH, HEIGHT = 13, 7.6
local TAB_SIZE = 0.8
-- Tabs hang off the left edge, overlapping the window slightly
local TAB_X = -TAB_SIZE + 0.1
local TAB_Y = 0.3

-- Tab order; the Color tab is special, the others are empty until their upgrades exist
local TABS = {
	{id = "color", title = "Color", tooltip = "Machine colors"},
	{id = "lights", title = "Lights", tooltip = "Lights"},
	{id = "drill", title = "Drill", tooltip = "Drill"},
	{id = "engine", title = "Engine", tooltip = "Engine"},
	{id = "thrusters", title = "Thrusters", tooltip = "Thrusters"},
	{id = "cargo", title = "Cargo", tooltip = "Cargo hold"},
	{id = "fuel", title = "Fuel tank", tooltip = "Fuel tank"},
	{id = "hull", title = "Hull", tooltip = "Hull"},
}

-- Less saturated colors plus neutral, warm and cold grays; each row is one family
local SWATCHES = {
	{"#1c1c1d", "#333334", "#4a4a4b", "#666667", "#858586", "#a6a6a7", "#c8c8c9", "#e6e6e7"},
	{"#2b2521", "#40372f", "#574b40", "#716354", "#8c7c6b", "#a89784", "#c4b5a1", "#ddd0bd"},
	{"#1f242b", "#303843", "#444f5d", "#5b6878", "#748294", "#8f9dad", "#aebbc8", "#cfd9e2"},
	{"#7a4a46", "#8a6a46", "#8a8446", "#4f7050", "#46787a", "#4a5f85", "#6a4f80", "#85506a"},
}

local SWATCH = 0.6
local SWATCH_GAP = 0.1
local SWATCH_SECTIONS = {
	{key = "frame", title = "Frame", x = 0.7},
	{key = "panel", title = "Panels", x = 6.9},
}
local SWATCH_Y = 2.2

local selected_tab = {}

local function tab_title(id)
	for _, tab in ipairs(TABS) do
		if tab.id == id then
			return tab.title
		end
	end
	return ""
end

local function color_tab(player)
	local chosen = st_machine.get_colors(player)
	local fs = {}
	for _, section in ipairs(SWATCH_SECTIONS) do
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(section.x, SWATCH_Y - 0.4, section.title)
		for row, family in ipairs(SWATCHES) do
			for col, hex in ipairs(family) do
				local x = section.x + (col - 1) * (SWATCH + SWATCH_GAP)
				local y = SWATCH_Y + (row - 1) * (SWATCH + SWATCH_GAP)
				local name = ("swatch_%s_%d_%d"):format(section.key, row, col)
				local img = core.formspec_escape("[fill:8x8:" .. hex)
				if hex == chosen[section.key] then
					fs[#fs + 1] = ("box[%g,%g;%g,%g;#e0a020]"):format(x - 0.05, y - 0.05, SWATCH + 0.1, SWATCH + 0.1)
				end
				fs[#fs + 1] = ("style[%s;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s]"):format(name, img, img, img)
				fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;]"):format(x, y, SWATCH, SWATCH, name)
			end
		end
	end
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local tab = selected_tab[name] or TABS[1].id
	local tabs = {}
	for i, def in ipairs(TABS) do
		tabs[i] = {id = def.id, image = "st_upgrades_tab_" .. def.id .. ".png", tooltip = def.tooltip}
	end
	local fs = {
		st_gui.header(WIDTH, HEIGHT, "Upgrades - " .. tab_title(tab)),
		st_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, vertical = true,
			tabs = tabs, selected = tab,
			bg = "st_upgrades_tab_bg.png", bg_selected = "st_upgrades_tab_bg_sel.png",
		}),
	}
	if tab == "color" then
		fs[#fs + 1] = color_tab(player)
	end
	return table.concat(fs)
end

function st_upgrades.show(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		core.show_formspec(player_name, FORMNAME, build(player))
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local tab = st_gui.tab_clicked(fields)
	if tab then
		selected_tab[player:get_player_name()] = tab
		st_upgrades.show(player:get_player_name())
		return
	end
	for field in pairs(fields) do
		local key, row, col = field:match("^swatch_(%a+)_(%d+)_(%d+)$")
		local hex = key and SWATCHES[tonumber(row)] and SWATCHES[tonumber(row)][tonumber(col)]
		if hex and st_machine.set_color(player, key, hex) then
			st_upgrades.show(player:get_player_name())
			return
		end
	end
end)

core.register_on_leaveplayer(function(player)
	selected_tab[player:get_player_name()] = nil
end)

st_interior.register_on_use(st_utils.constants.interact.upgrade, st_upgrades.show)
