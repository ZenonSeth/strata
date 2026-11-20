local FORMNAME = "str_upgrades:main"

local esc = core.formspec_escape

local WIDTH, HEIGHT = 15, 11.85
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

local PART_X = 0.7
local PART_W = WIDTH - 2 * PART_X
local PART_NAME_Y = 1.75
local PART_STAT_Y = 2.35
local TITLE_FONT, NORMAL_FONT = 1.5, 1.15

-- Part icons that exist, "str_upgrades_part_<category>_<level>.png"; other parts use their tab icon
local PART_ICONS = {}
for _, file in ipairs(core.get_dir_list(str_upgrades.modpath .. "/textures", false)) do
	PART_ICONS[file] = true
end

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

-- Materials in shop storage plus the cargo hold
local function held_materials(player)
	local held = str_storage.get(player)
	for material, count in pairs(str_machine.cargo.get(player)) do
		held[material] = (held[material] or 0) + count
	end
	return held
end

local function sorted_materials(from)
	local names = {}
	for material in pairs(from or {}) do
		names[#names + 1] = material
	end
	table.sort(names)
	return names
end

-- Whether storage plus cargo hold everything in from
local function has_materials(player, from)
	local held = held_materials(player)
	for material, need in pairs(from) do
		if (held[material] or 0) < need then
			return false
		end
	end
	return true
end

-- "equipped", "built" or "empty"
local function part_state(player, category, level)
	if stats.get_level(player, category.id).name == level.name then
		return "equipped"
	end
	return stats.has_level(player, category.id, level.name) and "built" or "empty"
end

-- Items made here land in the player's own bench list (shared by every part of the station), then are moved to the hotbar by hand
local BENCH_LIST, BENCH_SLOTS, BENCH_PAGE = "str_upgrades_bench", 16, 8
local BENCH_LABEL_Y, BENCH_Y = 8.4, 8.65
local HOTBAR_LABEL_Y, HOTBAR_Y = 10.0, 10.25
local PAGE_X, PAGE_W = PART_X + BENCH_PAGE * 1.25 - 0.25 + 0.2, 1.65

local bench_page = {}
-- Which hotbar the Create Items tab shows: "vehicle" or "foot"
local hotbar_view = {}

-- The bench label, one page of its slots and the page button
local function bench_fs(player)
	local pages = BENCH_SLOTS / BENCH_PAGE
	local page = math.min(bench_page[player:get_player_name()] or 1, pages)
	return ("label[%g,%g;Crafted items]"):format(PART_X, BENCH_LABEL_Y)
		.. ("list[current_player;%s;%g,%g;%d,1;%d]"):format(BENCH_LIST, PART_X, BENCH_Y, BENCH_PAGE, (page - 1) * BENCH_PAGE)
		.. ("button[%g,%g;%g,1;bench_page;Pg. %d/%d]"):format(PAGE_X, BENCH_Y, PAGE_W, page, pages)
end

-- From is taken from storage, then the cargo hold
local CRAFTABLES = {
	{name = "sign", category = "utility",
		item = "str_signs:sign", description = "Sign", count = 10, from = {graphite = 1, copper_plate = 1},
		info = "Placed behind the machine to mark the way"},
	{name = "platform", category = "utility",
		item = "str_platforms:platform", description = "Platform", count = 5, from = {bronze = 1, graphite = 1},
		info = "Placed below the machine to stand on\nCan be passed through if holding down/up while standing on/below it"},
	{name = "scanner", category = "utility",
		item = str_scanner.ITEM, description = "Scanner", count = 1, from = {copper_wire = 2, copper_plate = 1},
		info = "In the machine, point it at a node in your slice\nShows rock, mineral, tier and if your drill can dig it"},
	{name = "elevator_stop", category = "utility",
		item = "str_elevators:stop_station", description = "Elevator Stop", count = 1,
		from = {bronze = 2, lens_glass = 2, copper_wire = 1},
		info = "Placed below the surface, 250 m from other stops; needs a surface station in the column"},
	{name = "elevator_surface", category = "utility",
		item = "str_elevators:surface_station", description = "Elevator Surface", count = 1,
		from = {steel = 4, lens_glass = 4, silver_wire = 1, jade = 1},
		info = "Placed at the surface; the stops below it connect to it"},
	{name = "waypoint", category = "utility",
		item = "str_horizontal:waypoint", description = "Waypoint", count = 1,
		from = {lapis = 1, turquoise = 1, copper_wire = 2},
		info = "Placed at the surface, 100 m from other waypoints; travel between all waypoints"},
	{name = "explosive_weak", category = "explosive",
		item = "str_explosives:weak", description = "Weak explosive", count = 1,
		from = {coal = 1, bronze = 1},
		info = "Destroys nodes up to tier 4 in a circle of radius 2 around the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_line", category = "explosive",
		item = "str_explosives:line", description = "Line charge", count = 1,
		from = {steel = 1, coal = 1},
		info = "Horizontal: destroys nodes up to tier 6 in a row, 3 to each side of the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_tnt", category = "explosive",
		item = "str_explosives:tnt", description = "TNT", count = 1,
		from = {coal = 1, bronze = 1, sulphur = 1},
		info = "Destroys nodes up to tier 8 in a circle of radius 4 around the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_c4", category = "explosive",
		item = "str_explosives:c4", description = "C4", count = 1,
		from = {titanium_alloy = 1, oil = 1, sulphur = 2},
		info = "Destroys nodes up to tier 9 in a circle of radius 5 around the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
	{name = "explosive_c4_shaped", category = "explosive",
		item = "str_explosives:c4_shaped", description = "Shaped C4", count = 1,
		from = {titanium_alloy = 1, steel = 1, oil = 1, sulphur = 2},
		info = "Horizontal: destroys nodes up to tier 9 in a row, 4 to each side of the machine\nGround content is destroyed\nCarry at most 50 in the hotbar"},
}

-- Entries with recipes are listed only once any of those blueprints is owned
local lasers = str_machine_data.lasers
local laser_recipes = str_recipes.laser_recipes
for _, def in ipairs(lasers.lasers) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, category = "laser", item = def.item, description = def.description,
		count = 1, from = def.from, recipes = {str_recipes.item_recipe(def.name)},
		info = ("Fires a beam up to %d nodes long that breaks nodes up to tier %d\nUses %s per shot from a battery in the hotbar\n"
			.. "Needs a %s fitted in the hull"):format(def.range, def.tier, str_lasers.format_energy(def.shot_kj),
			lasers.mount.description:lower())}
end
for _, def in ipairs(lasers.batteries) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, category = "laser", item = def.item, description = def.description,
		count = 1, from = def.from, recipes = def.blueprint and {str_recipes.item_recipe(def.name)} or laser_recipes,
		info = ("Holds %s for lasers\nCarry it in the hotbar"):format(str_lasers.format_energy(def.capacity_kj))}
end

local HULL_UPGRADE_FROM = {
	["str_machine:hull_liquid_collection"] = {steel = 4, copper_wire = 2, lens_glass = 1},
	["str_machine:hull_lava_protection"] = {nickel_steel = 4, gold_wire = 2},
	["str_machine:hull_autorepair_1"] = {nickel_steel = 4, copper_wire = 2, garnet = 1},
	["str_machine:hull_autorepair_2"] = {titanium_alloy = 4, gold_wire = 2, aquamarine = 1},
	[lasers.mount.item] = lasers.mount.from,
}
for _, def in ipairs(str_machine.hull_slots.items) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, category = "hull", item = def.name, description = def.description,
		count = 1, from = HULL_UPGRADE_FROM[def.name], recipes = def.name == lasers.mount.item and laser_recipes or nil,
		info = def.info}
end
for _, def in ipairs(str_furnish.list) do
	CRAFTABLES[#CRAFTABLES + 1] = {name = def.name, category = "handheld", item = def.item, description = def.description,
		count = 1, from = def.from, recipes = {def.recipe}, info = def.info}
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

local CATEGORIES = {
	{id = "utility", title = "Utility"},
	{id = "explosive", title = "Explosives"},
	{id = "laser", title = "Lasers"},
	{id = "hull", title = "Hull upgrades"},
	{id = "handheld", title = "Hand hotbar"},
}

local GRID_NAME = "craft"
local GRID_Y, GRID_W, GRID_H, GRID_COLUMNS = 1.2, 7.6, 6.9, 4
local INFO_X = PART_X + GRID_W + 0.25
local INFO_W = PART_X + PART_W - INFO_X
local INFO_PAD = 0.25
local BIG_IMAGE = 1.1
local NEED_ROW_H, NEED_ICON = 0.42, 0.36
local CREATE_W, CREATE_H = 1.9, 0.75
local TEXT_SIZE = 15
local INFO_SIZE = 14

local selected_item = {}
-- player name -> tab id -> scroll value of its grid
local grid_scroll = {}

-- In CATEGORIES order
local function listed_craftables(player)
	local list = {}
	for _, cat in ipairs(CATEGORIES) do
		for _, def in ipairs(CRAFTABLES) do
			if def.category == cat.id and (not def.recipes or str_recipes.has_any(player, def.recipes)) then
				list[#list + 1] = def
			end
		end
	end
	return list
end

-- The selected item, or the first one listed
local function picked_craftable(player)
	local listed = listed_craftables(player)
	local chosen = selected_item[player:get_player_name()]
	for _, def in ipairs(listed) do
		if def.name == chosen then
			return def
		end
	end
	return listed[1]
end

-- How many times def can be made from the held materials; 0 for a hull upgrade already owned
local function craft_count(def, held, owned)
	if owned then
		return 0
	end
	local count
	for material, need in pairs(def.from) do
		local n = math.floor((held[material] or 0) / need)
		count = math.min(count or n, n)
	end
	return count or 0
end

local function item_label(def)
	return def.count > 1 and ("%s x%d"):format(def.description, def.count) or def.description
end

local function item_entries(player)
	local held = held_materials(player)
	local entries, category = {}, nil
	for _, def in ipairs(listed_craftables(player)) do
		if def.category ~= category then
			category = def.category
			for _, cat in ipairs(CATEGORIES) do
				if cat.id == category then
					entries[#entries + 1] = {header = cat.title, icon = "str_upgrades_cat_" .. cat.id .. ".png"}
				end
			end
		end
		local owned = already_owned(player, def)
		local count = craft_count(def, held, owned)
		entries[#entries + 1] = {
			id = def.name, item = def.item, label = item_label(def), tooltip = item_label(def), dim = count == 0,
			badge = owned and "Owned" or count > 0 and tostring(count) or nil, badge_color = str_gui.theme.equipped,
		}
	end
	return entries
end

-- One line of hypertext, centered vertically in its box; text is markup
local function info_text(x, y, w, h, text, color, halign)
	return ("hypertext[%g,%g;%g,%g;;<global margin=0 valign=middle halign=%s color=%s size=%d>%s]"):format(x, y, w, h,
		halign or "left", color or str_gui.theme.text, TEXT_SIZE, text)
end

-- The big image and the name beside it; image is {item = name} or {image = texture}
local function info_title(x, y, w, image, text)
	local fs = image.item and ("item_image[%g,%g;%g,%g;%s]"):format(x, y, BIG_IMAGE, BIG_IMAGE, image.item)
		or ("image[%g,%g;%g,%g;%s]"):format(x, y, BIG_IMAGE, BIG_IMAGE, esc(image.image))
	return fs .. info_text(x + BIG_IMAGE + 0.2, y, w - BIG_IMAGE - 0.2, BIG_IMAGE, text)
end

-- y of the "Needs" header so that it and the rows for `from` end just above the action row
local function needs_y(bottom, from)
	return bottom - CREATE_H - 0.2 - (#sorted_materials(from) + 1) * NEED_ROW_H
end

-- A "Needs"/"Have" header at y, then one row per material: icon, amount needed, and the held amount (red if short)
local function need_rows(x, y, w, from, held)
	local theme = str_gui.theme
	local fs = {
		info_text(x, y, w, NEED_ROW_H, "Needs", theme.muted),
		info_text(x, y, w, NEED_ROW_H, "Have", theme.muted, "right"),
	}
	for i, material in ipairs(sorted_materials(from)) do
		local need, have = from[material], held[material] or 0
		local row_y = y + i * NEED_ROW_H
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(x, row_y + (NEED_ROW_H - NEED_ICON) / 2, NEED_ICON, NEED_ICON,
			esc(str_materials.get(material).icon))
		fs[#fs + 1] = info_text(x + NEED_ICON + 0.15, row_y, w - NEED_ICON - 1.15, NEED_ROW_H,
			esc(("%d %s"):format(need, str_materials.get(material).description)))
		fs[#fs + 1] = info_text(x + w - 1, row_y, 1, NEED_ROW_H, tostring(have),
			have < need and theme.danger or theme.text, "right")
	end
	return table.concat(fs)
end

-- The status line ending at bottom, with an optional {field, label} button on its right
local function action_row(x, bottom, w, status, color, button)
	local fs = ""
	local status_w = w
	if button then
		fs = ("button[%g,%g;%g,%g;%s;%s]"):format(x + w - CREATE_W, bottom - CREATE_H, CREATE_W, CREATE_H,
			button[1], button[2])
		status_w = w - CREATE_W - 0.1
	end
	return fs .. info_text(x, bottom - CREATE_H, status_w, CREATE_H, esc(status), color)
end

-- The detail panel: image, name, info, each material needed against what is held, and Create
local function item_info(player, def)
	local theme = str_gui.theme
	local x, y, w = INFO_X + INFO_PAD, GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = GRID_Y + GRID_H - INFO_PAD
	local held = held_materials(player)
	local owned = already_owned(player, def)
	local count = craft_count(def, held, owned)
	local head_y = needs_y(bottom, def.from)
	local makes = def.count > 1 and ("\n<style color=%s>Makes %d</style>"):format(theme.muted, def.count) or ""
	local fs = {
		info_title(x, y, w, def, ("<b><style size=18>%s</style></b>%s"):format(esc(def.description), makes)),
		("hypertext[%g,%g;%g,%g;;<global margin=0 color=%s size=%d>%s]"):format(x, y + BIG_IMAGE + 0.15, w,
			head_y - y - BIG_IMAGE - 0.25, theme.text, INFO_SIZE, esc(def.info)),
		need_rows(x, head_y, w, def.from, held),
	}
	local status, color, button = ("Can make: %d"):format(count), count > 0 and theme.text or theme.muted, nil
	local stack = ItemStack(def.item .. " " .. def.count)
	if owned then
		status, color = "Already owned", theme.danger
	elseif count > 0 and not player:get_inventory():room_for_item(BENCH_LIST, stack) then
		status, color = "Crafted items full", theme.danger
	elseif count > 0 then
		button = {"create_item", "Create"}
	end
	fs[#fs + 1] = action_row(x, bottom, w, status, color, button)
	return table.concat(fs)
end

local function items_tab(player)
	local name = player:get_player_name()
	local picked = picked_craftable(player)
	local scroll = grid_scroll[name]
	local fs = {
		str_gui.tile_grid({
			x = PART_X, y = GRID_Y, w = GRID_W, h = GRID_H, name = GRID_NAME, columns = GRID_COLUMNS,
			scroll = scroll and scroll.items, entries = item_entries(player), selected = picked and picked.name,
		}),
		str_gui.input_bg(INFO_X, GRID_Y, INFO_W, GRID_H),
		picked and item_info(player, picked) or "",
	}
	fs[#fs + 1] = bench_fs(player)
	local view = hotbar_view[player:get_player_name()] or "vehicle"
	local hotbar = str_hotbar.list(player, view)
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(PART_X, HOTBAR_LABEL_Y, view == "foot" and "Hand hotbar" or "Machine hotbar")
	fs[#fs + 1] = ("list[current_player;%s;%g,%g;8,1;0.25]"):format(hotbar, PART_X, HOTBAR_Y)
	fs[#fs + 1] = ("button[%g,%g;%g,1;hotbar_view;%s]"):format(PAGE_X, HOTBAR_Y, PAGE_W,
		view == "foot" and "Machine" or "Hand")
	fs[#fs + 1] = ("listring[current_player;%s]listring[current_player;%s]"):format(BENCH_LIST, hotbar)
	return table.concat(fs)
end

local PART_HEAD_H = 1.4
local PART_COLUMNS, PART_NAME_LINES = 3, 2
local PART_GRID_Y = GRID_Y + PART_HEAD_H + 0.25
local PART_GRID_H = HEIGHT - 0.6 - PART_GRID_Y

-- The selected level, or the equipped one
local function picked_level(player, category)
	local name = player:get_player_name()
	local chosen = selected_level[name] and selected_level[name][category.id]
	for _, level in ipairs(listed_levels(player, category)) do
		if level.name == chosen then
			return level
		end
	end
	return stats.get_level(player, category.id)
end

-- {label, text} for the category's stat and each extra; a built part of a condition category shows its condition
local function stat_lines(player, category, level, built)
	local main = format_stat(category.stat, level.stats[category.stat.key])
	if category.condition and built then
		main = condition_text(player, category, level)
	end
	local lines = {{category.stat.label, main}}
	for _, extra in ipairs(category.extra or {}) do
		lines[#lines + 1] = {extra.label, format_stat(extra, level.stats[extra.key])}
	end
	return lines
end

local function part_icon(category, level, tab_icon)
	local file = ("str_upgrades_part_%s_%s.png"):format(category.id, level.name)
	return PART_ICONS[file] and file or tab_icon
end

local function part_entries(player, category, icon)
	local held = held_materials(player)
	local theme = str_gui.theme
	local entries = {}
	for _, level in ipairs(listed_levels(player, category)) do
		local state = part_state(player, category, level)
		local affordable = state ~= "empty" or (level.from and craft_count(level, held) > 0)
		entries[#entries + 1] = {
			id = level.name, image = part_icon(category, level, icon), label = level.description, tooltip = level.description, dim = not affordable,
			status = state == "equipped" and "Equipped" or state == "built" and "Built" or "",
			status_color = state == "equipped" and theme.equipped or theme.text,
		}
	end
	return entries
end

-- The equipped part across the top: icon, name and stats
local function equipped_strip(player, category, icon)
	local theme = str_gui.theme
	local equipped = stats.get_level(player, category.id)
	local parts = {}
	for _, line in ipairs(stat_lines(player, category, equipped, true)) do
		parts[#parts + 1] = ("<style color=%s>%s:</style> %s"):format(theme.muted, esc(line[1]), esc(line[2]))
	end
	local x, w = PART_X + INFO_PAD, PART_W - 2 * INFO_PAD
	return str_gui.input_bg(PART_X, GRID_Y, PART_W, PART_HEAD_H)
		.. info_title(x, GRID_Y + (PART_HEAD_H - BIG_IMAGE) / 2, w, {image = part_icon(category, equipped, icon)},
			("<b><style size=18 color=%s>%s</style></b>\n%s"):format(theme.equipped, esc(equipped.description),
			table.concat(parts, "     ")))
		.. info_text(x, GRID_Y, w, PART_HEAD_H, "Equipped", theme.muted, "right")
end

-- The detail panel: image, name, stats, the materials to build it, and Build or Equip
local function part_info(player, category, level, icon)
	local theme = str_gui.theme
	local x, y, w = INFO_X + INFO_PAD, PART_GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = PART_GRID_Y + PART_GRID_H - INFO_PAD
	local state = part_state(player, category, level)
	local fs = {info_title(x, y, w, {image = part_icon(category, level, icon)}, ("<b><style size=18>%s</style></b>"):format(esc(level.description)))}
	local lines = {}
	for _, line in ipairs(stat_lines(player, category, level, state ~= "empty")) do
		lines[#lines + 1] = ("<style color=%s>%s:</style> %s"):format(theme.muted, esc(line[1]), esc(line[2]))
	end
	local stats_y = y + BIG_IMAGE + 0.25
	fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;;<global margin=0 color=%s size=%d>%s]"):format(x, stats_y, w,
		needs_y(bottom, level.from) - stats_y - 0.1, theme.text, TEXT_SIZE, table.concat(lines, "\n"))
	local status, color, button = "Equipped", theme.equipped, nil
	if state == "built" then
		local can, reason = stats.can_equip(player, category.id, level.name)
		if can then
			status, color, button = "Built, in storage", theme.text, {"equip_part", "Equip"}
		else
			status, color = reason, theme.danger
		end
	elseif state == "empty" then
		local held = held_materials(player)
		fs[#fs + 1] = need_rows(x, needs_y(bottom, level.from), w, level.from, held)
		if craft_count(level, held) > 0 then
			status, color, button = "Not built", theme.text, {"build_part", "Build"}
		else
			status, color = "Not enough materials", theme.muted
		end
	end
	fs[#fs + 1] = action_row(x, bottom, w, status, color, button)
	return table.concat(fs)
end

local function category_tab(player, category, tab)
	local icon = "str_upgrades_tab_" .. tab .. ".png"
	local picked = picked_level(player, category)
	local scroll = grid_scroll[player:get_player_name()]
	return table.concat({
		equipped_strip(player, category, icon),
		str_gui.tile_grid({
			x = PART_X, y = PART_GRID_Y, w = GRID_W, h = PART_GRID_H, name = GRID_NAME, columns = PART_COLUMNS,
			name_lines = PART_NAME_LINES,
			scroll = scroll and scroll[tab], entries = part_entries(player, category, icon), selected = picked.name,
		}),
		str_gui.input_bg(INFO_X, PART_GRID_Y, INFO_W, PART_GRID_H),
		part_info(player, category, picked, icon),
	})
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
		fs[#fs + 1] = category_tab(player, str_machine_data.get_upgrade(TAB_CATEGORY[tab]), tab)
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

-- Takes the materials from shop storage, then the cargo hold, and marks the part built (equipped if above the current tier), if the recipe is owned and all are there
local function build_part(player, category, level)
	if not level or not level.from or stats.has_level(player, category.id, level.name)
			or not str_recipes.has(player, str_recipes.level_recipe(category.id, level.name)) then
		return
	end
	if not has_materials(player, level.from) then
		return
	end
	take_materials(player, level.from)
	stats.build_level(player, category.id, level.name)
	play_build_strikes(player)
	local equipped_name = stats.get_level(player, category.id).name
	for _, candidate in ipairs(category.levels) do
		if candidate.name == level.name then
			return
		elseif candidate.name == equipped_name then
			stats.equip_level(player, category.id, level.name)
			return
		end
	end
end

local function handle_item_fields(player, fields)
	local name = player:get_player_name()
	local def = picked_craftable(player)
	local clicked = str_gui.tile_clicked(fields, GRID_NAME, item_entries(player))
	if clicked then
		selected_item[name] = clicked
		def = picked_craftable(player)
		hotbar_view[name] = str_hotbar.kind(def.item)
	elseif fields.hotbar_view then
		hotbar_view[name] = hotbar_view[name] == "foot" and "vehicle" or "foot"
	elseif fields.create_item and def then
		local stack = ItemStack(def.item .. " " .. def.count)
		if not has_materials(player, def.from) or already_owned(player, def) or not player:get_inventory():room_for_item(BENCH_LIST, stack) then
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
	local level = picked_level(player, category)
	local clicked = str_gui.tile_clicked(fields, GRID_NAME, part_entries(player, category))
	if clicked then
		selected_level[name] = selected_level[name] or {}
		selected_level[name][category.id] = clicked
	elseif fields.build_part then
		build_part(player, category, level)
	elseif fields.equip_part then
		stats.equip_level(player, category.id, level.name)
		str_audio.sfx.play("upgrade_bolt", {player = player})
	else
		return
	end
	str_upgrades.show(name)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local scroll = str_gui.tile_scroll(fields, GRID_NAME)
	if scroll then
		local name = player:get_player_name()
		grid_scroll[name] = grid_scroll[name] or {}
		grid_scroll[name][selected_tab[name] or TABS[1].id] = scroll
	end
	if fields.quit then
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
	grid_scroll[player:get_player_name()] = nil
	selected_part[player:get_player_name()] = nil
	bench_page[player:get_player_name()] = nil
	hotbar_view[player:get_player_name()] = nil
end)

str_interior.register_on_use(str_utils.constants.interact.upgrade, str_upgrades.show)
