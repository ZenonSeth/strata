local FORMNAME = "str_upgrades:main"

local esc = core.formspec_escape

local WIDTH, HEIGHT = 13, 9.2
local TAB_SIZE = 1
-- Tabs sit on the top edge, overlapping the window slightly
local TAB_X = 0.4
local TAB_Y = -TAB_SIZE + 0.1

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
	{id = "hull_upgrades", title = "Hull Upgrades", tooltip = "Hull upgrades"},
	{id = "items", title = "Create Items", tooltip = "Create Items"},
}

-- Less saturated colors plus neutral, warm and cold grays; each row is one family
local SWATCHES = {
	{"#1c1c1d", "#333334", "#4a4a4b", "#666667", "#858586", "#a6a6a7", "#c8c8c9", "#e6e6e7"},
	{"#2b2521", "#40372f", "#574b40", "#716354", "#8c7c6b", "#a89784", "#c4b5a1", "#ddd0bd"},
	{"#1f242b", "#303843", "#444f5d", "#5b6878", "#748294", "#8f9dad", "#aebbc8", "#cfd9e2"},
	{"#a2807e", "#ad977e", "#ada97e", "#849b84", "#7ea0a2", "#808faa", "#9784a6", "#aa8497"},
	{"#f07a6e", "#f5a85e", "#f2e46a", "#86d886", "#6fdcdc", "#7aa8f2", "#b98af0", "#f28abf"},
	{"#c8382e", "#d9782a", "#d8c22e", "#4aa64a", "#2fa5a8", "#3a6fd0", "#8a4fc8", "#d04f8f"},
	{"#7a4a46", "#8a6a46", "#8a8446", "#4f7050", "#46787a", "#4a5f85", "#6a4f80", "#85506a"},
	{"#492c2a", "#53402a", "#534f2a", "#2f4330", "#2a4849", "#2c3950", "#402f4d", "#503040"},
}

local SWATCH = 0.6
local SWATCH_GAP = 0.1
local COLOR_PARTS = {
	{key = "frame", title = "Frame"},
	{key = "panel", title = "Panels"},
	{key = "spokes", title = "Rims"},
	{key = "thruster", title = "Thrusters"},
	{key = "ladder", title = "Ladder"},
}
local SWATCH_X, SWATCH_Y = 0.7, 2.6
local PART_ROW_Y, PART_ROW_H = 1.6, 0.7
local PART_TAB_W, PART_TAB_GAP = 2.2, 0.15
local GRID_X = (WIDTH - (#SWATCHES[1] * (SWATCH + SWATCH_GAP) - SWATCH_GAP)) / 2

-- Tabs that list the parts of an upgrade category (str_machine_data.upgrades)
local TAB_CATEGORY = {lights = "lights", fuel = "tank", hull = "hull", cargo = "cargo", drill = "drill", engine = "engine", thrusters = "thrusters"}

local PART_X, PART_W = 0.7, 11.6
local PART_NAME_Y = 1.75
local PART_STAT_Y = 2.35
local PART_TABLE_Y, PART_TABLE_H = 2.75, 3.6
local PART_BUTTON_Y, PART_BUTTON_H = 7.05, 0.8
local TITLE_FONT, NORMAL_FONT = 1.5, 1.15

local PART_COLUMN = {title = "Part", spec = "text,width=13,padding=0.3"}
local STAT_COLUMN = {spec = "text,width=7,padding=0.3"}
local CONDITION_COLUMN = {title = "Condition", spec = "text,width=8,padding=0.3"}
local STATE_COLUMN = {title = "State", spec = "text,width=6,padding=0.3"}

local selected_tab = {}
-- player name -> index into COLOR_PARTS
local selected_part = {}
-- player name -> category id -> selected level name
local selected_level = {}

local function tab_title(id)
	for _, tab in ipairs(TABS) do
		if tab.id == id then
			return tab.title
		end
	end
	return ""
end

local function color_tab(player)
	local index = selected_part[player:get_player_name()] or 1
	local key = COLOR_PARTS[index].key
	local current = str_machine.get_colors(player)[key]
	local fs = {}
	for i, part in ipairs(COLOR_PARTS) do
		local x = SWATCH_X + (i - 1) * (PART_TAB_W + PART_TAB_GAP)
		fs[#fs + 1] = ("button[%g,%g;%g,%g;color_part_%d;%s]"):format(x, PART_ROW_Y, PART_TAB_W, PART_ROW_H, i,
			core.formspec_escape(part.title))
		if i == index then
			fs[#fs + 1] = ("box[%g,%g;%g,0.06;#e0a020]"):format(x, PART_ROW_Y + PART_ROW_H + 0.02, PART_TAB_W)
		end
	end
	for row, family in ipairs(SWATCHES) do
		for col, hex in ipairs(family) do
			local x = GRID_X + (col - 1) * (SWATCH + SWATCH_GAP)
			local y = SWATCH_Y + (row - 1) * (SWATCH + SWATCH_GAP)
			local name = ("swatch_%d_%d"):format(row, col)
			local img = core.formspec_escape("[fill:8x8:" .. hex)
			if hex == current then
				fs[#fs + 1] = ("box[%g,%g;%g,%g;#e0a020]"):format(x - 0.05, y - 0.05, SWATCH + 0.1, SWATCH + 0.1)
			end
			fs[#fs + 1] = ("style[%s;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s]"):format(name, img, img, img)
			fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;]"):format(x, y, SWATCH, SWATCH, name)
		end
	end
	return table.concat(fs)
end

local stats = str_machine.stats

local format_stat = str_machine_data.format_stat

-- "75 / 115" for a part that keeps its own current value
local function condition_text(player, category, level)
	local current = str_machine.stats.get_part_value(player, category.id, level.name)
	return ("%d / %s"):format(math.ceil(current), format_stat(category.stat, level.stats[category.stat.key]))
end

-- The stock level, plus every level whose recipe is owned or that is already built
local function listed_levels(player, category)
	local list = {}
	for i, level in ipairs(category.levels) do
		if i == 1 or str_recipes.has(player, str_recipes.level_recipe(category.id, level.name))
				or stats.has_level(player, category.id, level.name) then
			list[#list + 1] = level
		end
	end
	return list
end

-- Text like "1 Bronze (have 0), 2 Iron ore (have 1)" and whether storage plus cargo hold all of it
-- plain leaves out the "(have N)" counts
local function needs(player, level, plain)
	local stored = str_storage.get(player)
	for material, count in pairs(str_machine.cargo.get(player)) do
		stored[material] = (stored[material] or 0) + count
	end
	local names = {}
	for material in pairs(level.from or {}) do
		names[#names + 1] = material
	end
	table.sort(names)
	local parts, missing = {}, {}
	for _, material in ipairs(names) do
		local need, have = level.from[material], stored[material] or 0
		local description = str_materials.get(material).description
		if have < need then
			missing[#missing + 1] = ("%d %s"):format(need - have, description)
		end
		parts[#parts + 1] = plain and ("%d %s"):format(need, description)
			or ("%d %s (have %d)"):format(need, description, have)
	end
	return table.concat(parts, ", "), #missing == 0, table.concat(missing, ", ")
end

-- "equipped", "built" or "empty"
local function part_state(player, category, level)
	if stats.get_level(player, category.id).name == level.name then
		return "equipped"
	end
	return stats.has_level(player, category.id, level.name) and "built" or "empty"
end

local STATE_TEXT = {equipped = "Equipped", built = "Built", empty = "-"}

local function category_tab(player, category)
	local name = player:get_player_name()
	local chosen = selected_level[name] and selected_level[name][category.id]
	local equipped = stats.get_level(player, category.id)
	local value = equipped.stats[category.stat.key]
	local stat_line = ("%s: %s"):format(category.stat.label,
		category.condition and condition_text(player, category, equipped) or format_stat(category.stat, value))
	for _, extra in ipairs(category.extra or {}) do
		stat_line = stat_line .. ("   %s: %s"):format(extra.label, format_stat(extra, equipped.stats[extra.key]))
	end

	local rows, selected, selected_level_def = {}, 0, nil
	for i, level in ipairs(listed_levels(player, category)) do
		local state = part_state(player, category, level)
		local _, affordable = needs(player, level)
		local cells = {level.description, format_stat(category.stat, level.stats[category.stat.key])}
		for _, extra in ipairs(category.extra or {}) do
			if extra.column ~= false then
				cells[#cells + 1] = format_stat(extra, level.stats[extra.key])
			end
		end
		if category.condition then
			cells[#cells + 1] = state == "empty" and "-" or condition_text(player, category, level)
		end
		cells[#cells + 1] = STATE_TEXT[state]
		rows[i] = {
			color = (state == "equipped" and str_gui.theme.equipped)
				or (state == "empty" and not affordable and str_gui.theme.muted) or str_gui.theme.text,
			cells = cells,
		}
		if level.name == chosen then
			selected, selected_level_def = i, level
		end
	end
	local columns = {PART_COLUMN, {title = category.stat.label, spec = STAT_COLUMN.spec}}
	for _, extra in ipairs(category.extra or {}) do
		if extra.column ~= false then
			local spec = extra.width and ("text,width=%g,padding=0.3"):format(extra.width) or STAT_COLUMN.spec
			columns[#columns + 1] = {title = extra.label, spec = spec}
		end
	end
	if category.condition then
		columns[#columns + 1] = CONDITION_COLUMN
	end
	columns[#columns + 1] = STATE_COLUMN

	local detail, buttons = "Select a part.", {}
	if selected_level_def then
		local state = part_state(player, category, selected_level_def)
		local text, ok = needs(player, selected_level_def)
		if state == "equipped" then
			detail = selected_level_def.description .. ": equipped."
		elseif state == "built" then
			detail = selected_level_def.description .. ": built, in storage."
			local can, reason = stats.can_equip(player, category.id, selected_level_def.name)
			if can then
				buttons[#buttons + 1] = {"equip_part", "Equip"}
			else
				detail = detail .. "\n" .. reason
			end
		else
			detail = ("%s: needs %s"):format(selected_level_def.description, text)
			if ok then
				buttons[#buttons + 1] = {"build_part", "Build"}
			end
		end
	end

	local fs = {
		("style_type[label;font_size=*%g;textcolor=%s]"):format(TITLE_FONT, str_gui.theme.equipped),
		("label[%g,%g;%s]"):format(PART_X, PART_NAME_Y, esc(equipped.description)),
		("style_type[label;font_size=*%g;textcolor=%s]"):format(NORMAL_FONT, str_gui.theme.equipped),
		("label[%g,%g;%s]"):format(PART_X, PART_STAT_Y, esc(stat_line)),
		("style_type[label;textcolor=%s]"):format(str_gui.theme.text),
		str_gui.list_table({
			x = PART_X, y = PART_TABLE_Y, w = PART_W, h = PART_TABLE_H, name = "parts",
			columns = columns, rows = rows, selected = selected,
		}),
		("label[%g,%g;%s]"):format(PART_X, PART_TABLE_Y + PART_TABLE_H + 0.4, esc(detail)),
	}
	for i, button in ipairs(buttons) do
		fs[#fs + 1] = ("button[%g,%g;3,%g;%s;%s]"):format(PART_X + (i - 1) * 3.2, PART_BUTTON_Y,
			PART_BUTTON_H, button[1], button[2])
	end
	return table.concat(fs)
end

-- Items made here land in the player's own bench list (shared by every part of the station), then are moved to the hotbar by hand
local BENCH_LIST, BENCH_SLOTS, BENCH_PAGE = "str_upgrades_bench", 16, 8
local ITEMS_Y, ITEMS_H = 1.1, 3.0
local CREATE_W = 3
local BENCH_LABEL_Y, BENCH_Y = 5.75, 6.0
local HOTBAR_LABEL_Y, HOTBAR_Y = 7.35, 7.6
local PAGE_X = PART_X + BENCH_PAGE * 1.25 - 0.25 + 0.2

local bench_page = {}

-- The bench label, one page of its slots and the page button
local function bench_fs(player)
	local pages = BENCH_SLOTS / BENCH_PAGE
	local page = math.min(bench_page[player:get_player_name()] or 1, pages)
	return ("label[%g,%g;Crafted items]"):format(PART_X, BENCH_LABEL_Y)
		.. ("list[current_player;%s;%g,%g;%d,1;%d]"):format(BENCH_LIST, PART_X, BENCH_Y, BENCH_PAGE, (page - 1) * BENCH_PAGE)
		.. ("button[%g,%g;%g,1;bench_page;Pg. %d/%d]"):format(PAGE_X, BENCH_Y, PART_X + PART_W - PAGE_X, page, pages)
end

-- From is taken from storage, then the cargo hold
local CRAFTABLES = {
	{name = "sign", item = "str_signs:sign", description = "Sign", count = 10, from = {graphite = 1, copper_plate = 1},
		info = "Placed behind the machine to mark the way"},
	{name = "platform", item = "str_platforms:platform", description = "Platform", count = 5, from = {bronze = 1, graphite = 1},
		info = "Placed below the machine to stand on\nCan be passed through if holding down/up while standing on/below it"},
	{name = "elevator_stop", item = "str_elevators:stop_station", description = "Elevator Stop", count = 1,
		from = {steel = 4, lens_glass = 2, copper_wire = 1},
		info = "Placed below the surface, 250 m from other stops; needs a surface station in the column"},
	{name = "elevator_surface", item = "str_elevators:surface_station", description = "Elevator Surface", count = 1,
		from = {steel = 8, lens_glass = 4, silver_wire = 1, amazonite = 1},
		info = "Placed at the surface; the stops below it connect to it"},
	{name = "waypoint", item = "str_horizontal:waypoint", description = "Waypoint", count = 1,
		from = {lapis = 1, turquoise = 1, copper_wire = 2},
		info = "Placed at the surface, 100 m from other waypoints; travel between all waypoints"},
	{name = "explosive_weak", item = "str_explosives:weak", description = "Weak explosive", count = 1,
		from = {coal = 1, bronze = 1},
		info = "Destroys nodes up to tier 4 in a circle of radius 2 around the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_line", item = "str_explosives:line", description = "Line charge", count = 1,
		from = {steel = 1, coal = 1},
		info = "Horizontal: destroys nodes up to tier 6 in a row, 3 to each side of the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_tnt", item = "str_explosives:tnt", description = "TNT", count = 1,
		from = {coal = 1, bronze = 1, sulphur = 1},
		info = "Destroys nodes up to tier 8 in a circle of radius 4 around the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_c4", item = "str_explosives:c4", description = "C4", count = 1,
		from = {titanium_alloy = 1, oil = 1, sulphur = 2},
		info = "Destroys nodes up to tier 9 in a circle of radius 5 around the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_c4_shaped", item = "str_explosives:c4_shaped", description = "Shaped C4", count = 1,
		from = {titanium_alloy = 2, oil = 1, sulphur = 2},
		info = "Horizontal: destroys nodes up to tier 9 in a row, 4 to each side of the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
}

-- Entries with recipes are listed only once any of those blueprints is owned
local lasers = str_machine_data.lasers
local laser_recipes = str_recipes.laser_recipes
for _, def in ipairs(lasers.lasers) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, item = def.item, description = def.description, count = 1,
		from = def.from, recipes = {str_recipes.item_recipe(def.name)},
		info = ("Fires a beam up to %d nodes long that breaks nodes up to tier %d\nUses %s per shot from a battery in the hotbar\n"
			.. "Needs a %s fitted in the hull"):format(def.range, def.tier, str_lasers.format_energy(def.shot_kj),
			lasers.mount.description:lower())}
end
for _, def in ipairs(lasers.batteries) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, item = def.item, description = def.description, count = 1,
		from = def.from, recipes = def.blueprint and {str_recipes.item_recipe(def.name)} or laser_recipes,
		info = ("Holds %s for lasers\nCarry it in the hotbar"):format(str_lasers.format_energy(def.capacity_kj))}
end

local HULL_UPGRADE_FROM = {
	["str_machine:hull_liquid_collection"] = {steel = 4, copper_wire = 2, lens_glass = 1},
	["str_machine:hull_lava_protection"] = {nickel_steel = 4, gold_wire = 2},
	[lasers.mount.item] = lasers.mount.from,
}
for _, def in ipairs(str_machine.hull_slots.items) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, item = def.name, description = def.description, count = 1,
		from = HULL_UPGRADE_FROM[def.name], recipes = def.name == lasers.mount.item and laser_recipes or nil,
		info = def.info}
end
str_upgrades.craftables = CRAFTABLES
-- Hull upgrades cannot be destroyed yet, so only one of each may exist
local function already_owned(player, def)
	local hull_slots = str_machine.hull_slots
	if not hull_slots.is_upgrade(def.item) then
		return false
	end
	return hull_slots.has(player, def.item) or player:get_inventory():contains_item(BENCH_LIST, def.item)
end

local ITEM_COLUMNS = {
	{title = "Item", spec = "text,width=11,padding=0.3"},
	{title = "Needs", spec = "text,width=22,padding=0.3"},
}

local selected_item = {}

local function listed_craftables(player)
	local list = {}
	for _, def in ipairs(CRAFTABLES) do
		if not def.recipes or str_recipes.has_any(player, def.recipes) then
			list[#list + 1] = def
		end
	end
	return list
end

local function items_tab(player)
	local chosen = selected_item[player:get_player_name()]
	local rows, selected, picked = {}, 0, nil
	for i, def in ipairs(listed_craftables(player)) do
		local text, ok = needs(player, def, true)
		local item = def.count > 1 and ("%s x%d"):format(def.description, def.count) or def.description
		rows[i] = {color = ok and str_gui.theme.text or str_gui.theme.muted, cells = {item, text}}
		if def.name == chosen then
			selected, picked = i, def
		end
	end
	local detail, create, missing = "Select an item.", false, nil
	if picked then
		local _, ok, short = needs(player, picked)
		detail = picked.description .. "\n" .. picked.info
		create = ok
		missing = not ok and ("Missing: " .. short)
		if already_owned(player, picked) then
			create, missing = false, "Already owned"
		end
	end
	local fs = {
		str_gui.list_table({
			x = PART_X, y = ITEMS_Y, w = PART_W, h = ITEMS_H, name = "items",
			columns = ITEM_COLUMNS, rows = rows, selected = selected,
		}),
		("hypertext[%g,%g;%g,%g;;<global color=%s>%s]"):format(PART_X + CREATE_W + 0.3, ITEMS_Y + ITEMS_H,
			PART_W - CREATE_W - 0.3, BENCH_LABEL_Y - 0.1 - ITEMS_Y - ITEMS_H, str_gui.theme.text, esc(detail)),
	}
	if create then
		fs[#fs + 1] = ("button[%g,%g;%g,%g;create_item;Create]"):format(
			PART_X, ITEMS_Y + ITEMS_H + 0.3, CREATE_W, PART_BUTTON_H)
	elseif missing then
		fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;;<global color=%s size=14>%s]"):format(PART_X,
			ITEMS_Y + ITEMS_H + 0.3, CREATE_W, BENCH_LABEL_Y - 0.4 - ITEMS_Y - ITEMS_H, str_gui.theme.danger,
			esc(missing))
	end
	fs[#fs + 1] = bench_fs(player)
	fs[#fs + 1] = ("label[%g,%g;Your hotbar]"):format(PART_X, HOTBAR_LABEL_Y)
	fs[#fs + 1] = ("list[current_player;main;%g,%g;8,1;0.25]"):format(PART_X, HOTBAR_Y)
	fs[#fs + 1] = ("listring[current_player;%s]listring[current_player;main]"):format(BENCH_LIST)
	return table.concat(fs)
end

local SLOTS_LABEL_Y, SLOTS_Y = 3.15, 3.4

local function hull_upgrades_tab(player)
	local hull_slots = str_machine.hull_slots
	local equipped = stats.get_level(player, "hull")
	local slots = stats.get(player).hull_slots or 0
	local fs = {
		("style_type[label;font_size=*%g;textcolor=%s]"):format(TITLE_FONT, str_gui.theme.equipped),
		("label[%g,%g;%s]"):format(PART_X, PART_NAME_Y, esc(equipped.description)),
		("style_type[label;font_size=*%g;textcolor=%s]"):format(NORMAL_FONT, str_gui.theme.equipped),
		("label[%g,%g;%s]"):format(PART_X, PART_STAT_Y, esc(("Upgrade slots: %d"):format(slots))),
		("style_type[label;textcolor=%s]"):format(str_gui.theme.text),
	}
	if slots > 0 then
		fs[#fs + 1] = ("label[%g,%g;Fitted upgrades]"):format(PART_X, SLOTS_LABEL_Y)
		fs[#fs + 1] = ("list[current_player;%s;%g,%g;%d,1;0.25]"):format(hull_slots.LIST, PART_X, SLOTS_Y, slots)
		fs[#fs + 1] = ("listring[current_player;%s]listring[current_player;%s]"):format(hull_slots.LIST, BENCH_LIST)
	else
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(PART_X, SLOTS_LABEL_Y,
			esc("This hull has no upgrade slots."))
	end
	fs[#fs + 1] = bench_fs(player)
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local tab = selected_tab[name] or TABS[1].id
	local tabs = {}
	for i, def in ipairs(TABS) do
		tabs[i] = {id = def.id, image = def.image or "str_upgrades_tab_" .. def.id .. ".png", tooltip = def.tooltip}
	end
	local fs = {
		str_gui.header(WIDTH, HEIGHT, "Upgrades - " .. tab_title(tab)),
		str_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE,
			tabs = tabs, selected = tab,
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
		}),
	}
	if tab == "color" then
		fs[#fs + 1] = color_tab(player)
	elseif tab == "items" then
		fs[#fs + 1] = items_tab(player)
	elseif tab == "hull_upgrades" then
		fs[#fs + 1] = hull_upgrades_tab(player)
	elseif TAB_CATEGORY[tab] then
		fs[#fs + 1] = category_tab(player, str_machine_data.get_upgrade(TAB_CATEGORY[tab]))
	end
	return table.concat(fs)
end

function str_upgrades.show(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		core.show_formspec(player_name, FORMNAME, build(player))
	end
end

str_audio.sfx.register("upgrade_bolt", {sound = "str_upgrades_bolt", gain = 0.4})
str_audio.sfx.register("upgrade_strike", {sound = "str_upgrades_metal_strike", gain = 0.4})
str_audio.sfx.register("upgrade_spray", {sound = "str_upgrades_spray_hiss", gain = 0.4})

local STRIKE_GAP = 0.3

local function play_build_strikes(player)
	local name = player:get_player_name()
	str_audio.sfx.play("upgrade_strike", {player = player})
	core.after(STRIKE_GAP, function()
		local p = core.get_player_by_name(name)
		if p then
			str_audio.sfx.play("upgrade_strike", {player = p})
		end
	end)
end

local function take_materials(player, from)
	for material, amount in pairs(from) do
		amount = amount - str_storage.remove(player, material, amount)
		if amount > 0 then
			str_machine.cargo.remove(player, material, amount)
		end
	end
end

-- Takes the materials from shop storage, then the cargo hold, and marks the part built, if the recipe is owned and all are there
local function build_part(player, category, level)
	if not level or not level.from or stats.has_level(player, category.id, level.name)
			or not str_recipes.has(player, str_recipes.level_recipe(category.id, level.name)) then
		return
	end
	local _, ok = needs(player, level)
	if not ok then
		return
	end
	take_materials(player, level.from)
	stats.build_level(player, category.id, level.name)
	play_build_strikes(player)
end

local function handle_item_fields(player, fields)
	local name = player:get_player_name()
	local listed = listed_craftables(player)
	local def
	for _, candidate in ipairs(listed) do
		if candidate.name == selected_item[name] then
			def = candidate
		end
	end
	if fields.items then
		local event = core.explode_table_event(fields.items)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		selected_item[name] = listed[event.row] and listed[event.row].name
	elseif fields.create_item and def then
		local stack = ItemStack(def.item .. " " .. def.count)
		local _, ok = needs(player, def)
		if not ok or already_owned(player, def) or not player:get_inventory():room_for_item(BENCH_LIST, stack) then
			return
		end
		take_materials(player, def.from)
		player:get_inventory():add_item(BENCH_LIST, stack)
		play_build_strikes(player)
	else
		return
	end
	str_upgrades.show(name)
end

local function handle_category_fields(player, category, fields)
	local name = player:get_player_name()
	selected_level[name] = selected_level[name] or {}
	local chosen = selected_level[name][category.id]
	local level
	for _, candidate in ipairs(category.levels) do
		if candidate.name == chosen then
			level = candidate
		end
	end
	if fields.build_part then
		build_part(player, category, level)
	elseif fields.equip_part and level then
		stats.equip_level(player, category.id, level.name)
		str_audio.sfx.play("upgrade_bolt", {player = player})
	elseif fields.parts then
		local event = core.explode_table_event(fields.parts)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		local picked = listed_levels(player, category)[event.row]
		selected_level[name][category.id] = picked and picked.name
	else
		return
	end
	str_upgrades.show(name)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local tab = str_gui.tab_clicked(fields)
	if tab then
		selected_tab[player:get_player_name()] = tab
		str_upgrades.show(player:get_player_name())
		return
	end
	if fields.bench_page then
		local name = player:get_player_name()
		bench_page[name] = (bench_page[name] or 1) % (BENCH_SLOTS / BENCH_PAGE) + 1
		str_upgrades.show(name)
		return
	end
	if selected_tab[player:get_player_name()] == "items" then
		handle_item_fields(player, fields)
		return
	end
	local category = str_machine_data.get_upgrade(TAB_CATEGORY[selected_tab[player:get_player_name()] or ""] or "")
	if category then
		handle_category_fields(player, category, fields)
		return
	end
	local name = player:get_player_name()
	if (selected_tab[name] or TABS[1].id) ~= "color" then
		return
	end
	local changed = false
	for i in ipairs(COLOR_PARTS) do
		if fields["color_part_" .. i] and i ~= (selected_part[name] or 1) then
			selected_part[name] = i
			changed = true
		end
	end
	local key = COLOR_PARTS[selected_part[name] or 1].key
	for field in pairs(fields) do
		local row, col = field:match("^swatch_(%d+)_(%d+)$")
		local hex = row and SWATCHES[tonumber(row)] and SWATCHES[tonumber(row)][tonumber(col)]
		if hex then
			if str_machine.set_color(player, key, hex) then
				str_audio.sfx.play("upgrade_spray", {player = player})
				changed = true
			end
			break
		end
	end
	if changed then
		str_upgrades.show(name)
	end
end)

local function craftable_item(name)
	for _, def in ipairs(CRAFTABLES) do
		if def.item == name then
			return true
		end
	end
	return false
end

core.register_allow_player_inventory_action(function(_, action, inv, info)
	if action == "move" and info.to_list == BENCH_LIST then
		return craftable_item(inv:get_stack(info.from_list, info.from_index):get_name()) and info.count or 0
	elseif action == "put" and info.listname == BENCH_LIST then
		return craftable_item(info.stack:get_name()) and info.stack:get_count() or 0
	end
end)

core.register_on_joinplayer(function(player)
	player:get_inventory():set_size(BENCH_LIST, BENCH_SLOTS)
end)

core.register_on_leaveplayer(function(player)
	selected_tab[player:get_player_name()] = nil
	selected_level[player:get_player_name()] = nil
	selected_item[player:get_player_name()] = nil
	selected_part[player:get_player_name()] = nil
	bench_page[player:get_player_name()] = nil
end)

str_interior.register_on_use(str_utils.constants.interact.upgrade, str_upgrades.show)
