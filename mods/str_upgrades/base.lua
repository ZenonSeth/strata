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
	{id = "items", title = "Create Items", tooltip = "Create Items"},
}

-- Less saturated colors plus neutral, warm and cold grays; each row is one family
local SWATCHES = {
	{"#1c1c1d", "#333334", "#4a4a4b", "#666667", "#858586", "#a6a6a7", "#c8c8c9", "#e6e6e7"},
	{"#2b2521", "#40372f", "#574b40", "#716354", "#8c7c6b", "#a89784", "#c4b5a1", "#ddd0bd"},
	{"#1f242b", "#303843", "#444f5d", "#5b6878", "#748294", "#8f9dad", "#aebbc8", "#cfd9e2"},
	{"#a2807e", "#ad977e", "#ada97e", "#849b84", "#7ea0a2", "#808faa", "#9784a6", "#aa8497"},
	{"#7a4a46", "#8a6a46", "#8a8446", "#4f7050", "#46787a", "#4a5f85", "#6a4f80", "#85506a"},
	{"#492c2a", "#53402a", "#534f2a", "#2f4330", "#2a4849", "#2c3950", "#402f4d", "#503040"},
}

local SWATCH = 0.6
local SWATCH_GAP = 0.1
local SWATCH_SECTIONS = {
	{key = "frame", title = "Frame", x = 0.7},
	{key = "panel", title = "Panels", x = 6.9},
}
local SWATCH_Y = 2.2

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
	local chosen = str_machine.get_colors(player)
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
	local parts, ok = {}, true
	for _, material in ipairs(names) do
		local need, have = level.from[material], stored[material] or 0
		if have < need then
			ok = false
		end
		local description = str_materials.get(material).description
		parts[#parts + 1] = plain and ("%d %s"):format(need, description)
			or ("%d %s (have %d)"):format(need, description, have)
	end
	return table.concat(parts, ", "), ok
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
			cells[#cells + 1] = format_stat(extra, level.stats[extra.key])
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
		local spec = extra.width and ("text,width=%g,padding=0.3"):format(extra.width) or STAT_COLUMN.spec
		columns[#columns + 1] = {title = extra.label, spec = spec}
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
local BENCH_LIST, BENCH_SLOTS = "str_upgrades_bench", 8
local ITEMS_Y, ITEMS_H = 1.1, 3.0
local CREATE_W = 3
local BENCH_LABEL_Y, BENCH_Y = 5.75, 6.0
local HOTBAR_LABEL_Y, HOTBAR_Y = 7.35, 7.6

-- From is taken from storage, then the cargo hold
local CRAFTABLES = {
	{name = "sign", item = "str_signs:sign", description = "Sign", count = 10, from = {lead = 1, coal = 1},
		info = "Placed behind the machine to mark the way"},
	{name = "platform", item = "str_platforms:platform", description = "Platform", count = 5, from = {steel = 1},
		info = "Placed below the machine to stand on; dig it from above"},
	{name = "elevator_stop", item = "str_elevators:stop_station", description = "Elevator Stop", count = 1,
		from = {steel = 4, lens_glass = 2, copper_wire = 1},
		info = "Placed below the surface, 250 m from other stops; needs a surface station in the column"},
	{name = "elevator_surface", item = "str_elevators:surface_station", description = "Elevator Surface", count = 1,
		from = {steel = 8, lens_glass = 4, gold_wire = 1, amazonite = 1},
		info = "Placed at the surface; the stops below it connect to it"},
}
local ITEM_COLUMNS = {
	{title = "Item", spec = "text,width=11,padding=0.3"},
	{title = "Needs", spec = "text,width=22,padding=0.3"},
}

local selected_item = {}

local function items_tab(player)
	local chosen = selected_item[player:get_player_name()]
	local rows, selected, picked = {}, 0, nil
	for i, def in ipairs(CRAFTABLES) do
		local text, ok = needs(player, def, true)
		local item = def.count > 1 and ("%s x%d"):format(def.description, def.count) or def.description
		rows[i] = {color = ok and str_gui.theme.text or str_gui.theme.muted, cells = {item, text}}
		if def.name == chosen then
			selected, picked = i, def
		end
	end
	local detail, create = "Select an item.", false
	if picked then
		local _, ok = needs(player, picked)
		detail = picked.description .. "\n" .. picked.info
		create = ok
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
	end
	fs[#fs + 1] = ("label[%g,%g;Crafted items]"):format(PART_X, BENCH_LABEL_Y)
	fs[#fs + 1] = ("list[current_player;%s;%g,%g;%d,1;0.25]"):format(BENCH_LIST, PART_X, BENCH_Y, BENCH_SLOTS)
	fs[#fs + 1] = ("label[%g,%g;Your hotbar]"):format(PART_X, HOTBAR_LABEL_Y)
	fs[#fs + 1] = ("list[current_player;main;%g,%g;8,1;0.25]"):format(PART_X, HOTBAR_Y)
	fs[#fs + 1] = ("listring[current_player;%s]listring[current_player;main]"):format(BENCH_LIST)
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

str_audio.sfx.register("upgrade_bolt", {sound = "str_upgrades_bolt"})
str_audio.sfx.register("upgrade_strike", {sound = "str_upgrades_metal_strike"})

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
	local def
	for _, candidate in ipairs(CRAFTABLES) do
		if candidate.name == selected_item[name] then
			def = candidate
		end
	end
	if fields.items then
		local event = core.explode_table_event(fields.items)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		selected_item[name] = CRAFTABLES[event.row] and CRAFTABLES[event.row].name
	elseif fields.create_item and def then
		local stack = ItemStack(def.item .. " " .. def.count)
		local _, ok = needs(player, def)
		if not ok or not player:get_inventory():room_for_item(BENCH_LIST, stack) then
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
	if selected_tab[player:get_player_name()] == "items" then
		handle_item_fields(player, fields)
		return
	end
	local category = str_machine_data.get_upgrade(TAB_CATEGORY[selected_tab[player:get_player_name()] or ""] or "")
	if category then
		handle_category_fields(player, category, fields)
		return
	end
	for field in pairs(fields) do
		local key, row, col = field:match("^swatch_(%a+)_(%d+)_(%d+)$")
		local hex = key and SWATCHES[tonumber(row)] and SWATCHES[tonumber(row)][tonumber(col)]
		if hex and str_machine.set_color(player, key, hex) then
			str_upgrades.show(player:get_player_name())
			return
		end
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
end)

str_interior.register_on_use(str_utils.constants.interact.upgrade, str_upgrades.show)
