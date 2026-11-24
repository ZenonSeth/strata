local FORMNAME = "str_company:main"
local WIDTH, HEIGHT = 15, 11.85
local TAB_W, TAB_H = 2.2, 0.8
local TAB_X = 0.4
local TAB_Y = -TAB_H

local TABS = {
	{id = "sell", title = "Sell"},
	{id = "recipes", title = "Blueprints"},
	{id = "consumables", title = "Consumables"},
	{id = "buyback", title = "Buy Back"},
	{id = "debt", title = "Debt"},
}
local DEFAULT_TAB = "sell"

local TABLE_X, TABLE_W = 0.4, WIDTH - 0.8
local TABLE_Y = str_gui.CONTENT_Y
local TABLE_H = HEIGHT - TABLE_Y - 2.8
local BUTTON_Y = TABLE_Y + TABLE_H + 0.8
local BUTTON_H = 0.8

local esc = core.formspec_escape
local num = str_inventory.num
local resources = str_player_resources
local format_credits = resources.format_credits

str_audio.sfx.register("shop_register", {sound = "str_company_register"})

-- Crafted machine items sell like consumables, valued at their material cost per item
for _, def in ipairs(str_upgrades.craftables) do
	local cost = 0
	for material, amount in pairs(def.from or {}) do
		cost = cost + str_materials.get(material).price * amount
	end
	if cost > 0 and not def.refill and str_hotbar.kind(def.item) == "vehicle" then
		str_consumables.register_sellable(def.item, cost / def.count)
	end
end

local function play_register(player)
	str_audio.sfx.play("shop_register", {player = player})
end

local selected_tab = {}
-- Credits when the window was opened, for the change shown next to the credits
local visit_start = {}
local GAIN_COLOR = "#7ccf6a"
local selected_item = {}
local debt_message = {}

local SUB_W, SUB_H = 2.6, 0.8
local SOURCES = {
	{id = "cargo", title = "Cargo", store = function(player) return str_machine.cargo end, empty = "The hold is empty.", label = "Hold"},
	{id = "storage", title = "Storage", store = function(player) return str_storage end, empty = "The storage is empty.", label = "Storage"},
}
local source_by_id = {}
for _, src in ipairs(SOURCES) do
	source_by_id[src.id] = src
end
local sell_source = {}

local function current_source(name)
	return source_by_id[sell_source[name]] or SOURCES[1]
end

local function has_no_uses(def)
	return def.kind ~= "relic" and not str_upgrades.has_uses(def.name)
end

-- Tile grid on the left, detail panel on the right
local GRID_NAME = "shop"
local GRID_X, GRID_W, GRID_COLUMNS, NAME_LINES = TABLE_X, 8.2, 4, 2
local INFO_X = GRID_X + GRID_W + 0.25
local INFO_W = WIDTH - TABLE_X - INFO_X
local INFO_PAD = 0.25
local INFO_SIZE = 15
local ACTION_BUTTON_W = 2.4
-- player name -> tab id -> scroll value of its grid
local grid_scroll = {}

local function grid(name, y, h, entries, selected)
	local scroll = grid_scroll[name]
	return str_gui.tile_grid({
		x = GRID_X, y = y, w = GRID_W, h = h, name = GRID_NAME, columns = GRID_COLUMNS, name_lines = NAME_LINES,
		scroll = scroll and scroll[selected_tab[name] or DEFAULT_TAB], entries = entries, selected = selected,
	})
end

-- The selected id if it is listed, else the first listed one
local function picked_id(entries, chosen)
	local first
	for _, entry in ipairs(entries) do
		if entry.id == chosen and chosen then
			return chosen
		end
		first = first or entry.id
	end
	return first
end

-- Lines as hypertext: {label, value} with a muted label, {text} all muted, or plain text
local function info_lines(x, y, w, h, lines)
	local muted = str_gui.theme.muted
	local text = {}
	for i, line in ipairs(lines) do
		if type(line) ~= "table" then
			text[i] = esc(line)
		elseif #line == 1 then
			text[i] = ("<style color=%s>%s</style>"):format(muted, esc(line[1]))
		else
			text[i] = ("<style color=%s>%s:</style> %s"):format(muted, esc(line[1]), esc(line[2]))
		end
	end
	return ("hypertext[%g,%g;%g,%g;;<global margin=0 color=%s size=%d>%s]"):format(x, y, w, h, str_gui.theme.text,
		INFO_SIZE, table.concat(text, "\n"))
end

local function info_heading(text)
	return ("<b><style size=18>%s</style></b>"):format(esc(text))
end

local SELL_GRID_Y = TABLE_Y + SUB_H + 0.25
local SELL_GRID_H = HEIGHT - 1 - SELL_GRID_Y
local SELL_ALL_W = 3.4

local function sell_note(def)
	if def.kind == "relic" then
		return "Relic"
	end
	return has_no_uses(def) and "No uses: no recipe or upgrade needs it" or nil
end

local function sell_entries(player, name)
	local entries = {}
	for i, row in ipairs(str_inventory.rows(current_source(name).store().get(player))) do
		local def = row.def
		local note = sell_note(def)
		entries[i] = {
			id = def.name, image = def.icon, label = def.description, badge = num(row.count),
			status = format_credits(row.count * def.price), row = row,
			tooltip = note and (def.description .. "\n" .. note) or def.description,
		}
	end
	return entries
end

local function sell_info(entry, src)
	local x, y, w = INFO_X + INFO_PAD, SELL_GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = SELL_GRID_Y + SELL_GRID_H - INFO_PAD
	if not entry then
		return str_gui.info_text(x, y, w, 0.6, esc(src.empty), str_gui.theme.muted)
	end
	local def, count = entry.row.def, entry.row.count
	local lines = {
		{"Price each", format_credits(def.price) .. " credits"},
		{"Units", num(count)},
		{"Total", format_credits(count * def.price) .. " credits"},
	}
	local note = sell_note(def)
	if note then
		lines[#lines + 1] = ""
		lines[#lines + 1] = note
	end
	local top = y + str_gui.INFO_IMAGE + 0.25
	return table.concat({
		str_gui.info_title(x, y, w, {image = def.icon}, info_heading(def.description)),
		info_lines(x, top, w, bottom - str_gui.ACTION_H - 0.2 - top, lines),
		str_gui.action_row(x, bottom, w, nil, nil, {{"sell_one", "Sell 1"}, {"sell_stack", "Sell All"}}),
	})
end

local function sell_tab(player, name)
	local src = current_source(name)
	local entries = sell_entries(player, name)
	local picked = picked_id(entries, selected_item[name])
	local total_value, any_no_uses, picked_entry = 0, false, nil
	for _, entry in ipairs(entries) do
		total_value = total_value + entry.row.count * entry.row.def.price
		any_no_uses = any_no_uses or has_no_uses(entry.row.def)
		if entry.id == picked then
			picked_entry = entry
		end
	end
	local fs = {}
	for i, other in ipairs(SOURCES) do
		local btn = "sell_src_" .. other.id
		fs[#fs + 1] = ("style[%s;bgimg=%s;bgimg_pressed=%s]"):format(btn,
			other == src and "str_upgrades_tab_bg_sel.png" or "str_upgrades_tab_bg.png", "str_upgrades_tab_bg_sel.png")
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(GRID_X + (i - 1) * (SUB_W + 0.2), TABLE_Y, SUB_W, SUB_H, btn, other.title)
	end
	local right = WIDTH - TABLE_X
	if #entries > 0 then
		right = right - SELL_ALL_W
		fs[#fs + 1] = ("button[%g,%g;%g,%g;sell_all;Sell Everything]"):format(right, TABLE_Y, SELL_ALL_W, SUB_H)
		right = right - 0.2
	end
	if any_no_uses then
		fs[#fs + 1] = ("button[%g,%g;%g,%g;sell_no_uses;Sell (no uses)]"):format(right - SELL_ALL_W, TABLE_Y, SELL_ALL_W, SUB_H)
	end
	fs[#fs + 1] = grid(name, SELL_GRID_Y, SELL_GRID_H, entries, picked)
	fs[#fs + 1] = str_gui.input_bg(INFO_X, SELL_GRID_Y, INFO_W, SELL_GRID_H)
	fs[#fs + 1] = sell_info(picked_entry, src)
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, HEIGHT - 0.45,
		esc(("%s value: %s credits"):format(src.label, format_credits(total_value))))
	return table.concat(fs)
end

local DIM_TEXT = "#b0aa9e"
-- A row of filter buttons (all, then one per section) above the grid
local FILTER_SIZE, FILTER_GAP, FILTER_ICON, FILTER_TIER_W = 1, 0.1, 0.5, 0.6
local FILTER_CLEAR = esc("[fill:1x1:#00000000")
local FILTER_HOVER = esc("[fill:1x1:#ffffff14")
local RECIPE_GRID_Y = TABLE_Y + FILTER_SIZE + 0.25
local RECIPE_GRID_H = HEIGHT - 0.6 - RECIPE_GRID_Y
-- player name -> section key shown, nil for all
local recipe_filter = {}

local category_titles = {}
for _, category in ipairs(str_machine_data.upgrades) do
	category_titles[category.id] = category.title
end

-- Created item and Create Items entry of each item blueprint
local blueprint_item, blueprint_def = {}, {}
for _, def in ipairs(str_upgrades.craftables) do
	if def.recipes and not def.refill then
		blueprint_item[str_recipes.item_recipe(def.name)] = def.item
		blueprint_def[str_recipes.item_recipe(def.name)] = def
	end
end

local recipe_order = {}
for i, recipe in ipairs(str_recipes.list) do
	recipe_order[recipe.name] = i
end

-- The upgrade level a recipe builds and its tier (level.tier, else the drill tier, else its place in the category)
local function find_level(recipe)
	local category = str_machine_data.get_upgrade(recipe.kind)
	for i, level in ipairs(category and category.levels or {}) do
		if str_recipes.level_recipe(recipe.kind, level.name) == recipe.name then
			return level, level.tier or level.stats.drill_tier or i
		end
	end
end

-- Section sort key, title and header icon
local function recipe_section(recipe)
	if recipe.kind == "material" then
		return 0, "Smelting recipes", "str_company_recipe.png"
	elseif recipe.kind == "item" then
		return 1000, "Item blueprints", "str_company_item.png"
	end
	local _, tier = find_level(recipe)
	return tier or 999, ("Digger upgrades - Tier %d"):format(tier or 0), "str_company_upgrade.png"
end

-- 1 buyable, 2 locked, 3 owned, or nil when not shown (no ingredient found yet)
local function recipe_state(player, recipe)
	if recipe.hidden then
		return nil
	elseif str_recipes.has(player, recipe.name) then
		return 3
	elseif str_recipes.is_available(player, recipe.name) then
		return 1
	elseif str_recipes.has_progress(player, recipe.name) then
		return 2
	end
end

-- Shown recipes (only section `filter` if given) by section, then buyable, locked, owned, then price
local function visible_recipes(player, filter)
	local list, key = {}, {}
	for _, recipe in ipairs(str_recipes.list) do
		local state = recipe_state(player, recipe)
		if state and (not filter or recipe_section(recipe) == filter) then
			list[#list + 1] = recipe
			key[recipe.name] = {recipe_section(recipe), state}
		end
	end
	table.sort(list, function(a, b)
		local ka, kb = key[a.name], key[b.name]
		if ka[1] ~= kb[1] then
			return ka[1] < kb[1]
		elseif ka[2] ~= kb[2] then
			return ka[2] < kb[2]
		elseif a.price ~= b.price then
			return a.price < b.price
		end
		return recipe_order[a.name] < recipe_order[b.name]
	end)
	return list
end

-- {item = name} or {image = texture}
local function recipe_image(recipe)
	if recipe.kind == "material" then
		return {image = str_materials.get(recipe.name).icon}
	elseif recipe.kind == "item" then
		local item = blueprint_item[recipe.name]
		return item and {item = item} or {image = "str_company_item.png"}
	end
	local level = find_level(recipe)
	return {image = level and str_upgrades.part_icon(recipe.kind, level.name) or "str_company_upgrade.png"}
end

local function recipe_entries(player, name)
	local theme = str_gui.theme
	local entries, section = {}, nil
	for _, recipe in ipairs(visible_recipes(player, recipe_filter[name])) do
		local _, title, icon = recipe_section(recipe)
		if title ~= section then
			section = title
			entries[#entries + 1] = {header = title, icon = icon}
		end
		local state = recipe_state(player, recipe)
		local image = recipe_image(recipe)
		entries[#entries + 1] = {
			id = recipe.name, item = image.item, image = image.image, label = recipe.description, tooltip = recipe.description,
			dim = state == 2,
			status = state == 3 and "Owned" or state == 1 and format_credits(recipe.price) or "Locked",
			status_color = state == 3 and theme.equipped or state == 2 and theme.muted or theme.text,
		}
	end
	return entries
end

local function recipe_type(recipe)
	if recipe.kind == "material" then
		return "Smelting recipe"
	elseif recipe.kind == "item" then
		return "Item blueprint"
	end
	local _, tier = find_level(recipe)
	return ("Upgrade for %s, tier %d"):format((category_titles[recipe.kind] or recipe.kind):lower(), tier or 0)
end

-- Same stat lines as the Upgrades window
local function recipe_stats(recipe)
	local def = blueprint_def[recipe.name]
	if def then
		return def.info and def.info:split("\n") or {}
	end
	local level, category = find_level(recipe), str_machine_data.get_upgrade(recipe.kind)
	if not level then
		return {}
	end
	local lines = {}
	for _, stat in ipairs({category.stat, unpack(category.extra or {})}) do
		lines[#lines + 1] = {stat.label, str_machine_data.format_stat(stat, level.stats[stat.key])}
	end
	return lines
end

-- Ingredients as icon rows; ones the player has not found yet show as ???
local function ingredient_rows(player, recipe)
	local rows = {}
	for input, amount in pairs(recipe.from) do
		local found = str_recipes.has_found(player, input)
		local def = str_materials.get(input)
		rows[#rows + 1] = {icon = found and def.icon or nil, text = amount .. " " .. (found and def.description or "???"),
			sort = found and def.description or "~"}
	end
	table.sort(rows, function(a, b) return a.sort < b.sort end)
	return rows
end

local function recipe_info(player, recipe)
	local theme = str_gui.theme
	local x, y, w = INFO_X + INFO_PAD, RECIPE_GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = RECIPE_GRID_Y + RECIPE_GRID_H - INFO_PAD
	local state = recipe_state(player, recipe)
	local rows = ingredient_rows(player, recipe)
	local needs_y = bottom - str_gui.ACTION_H - 0.2 - (#rows + 1) * str_gui.ICON_ROW_H
	local fs = {str_gui.info_title(x, y, w, recipe_image(recipe), info_heading(recipe.description))}
	local lines = {{recipe_type(recipe)}}
	if state ~= 2 then
		lines[2] = ""
		for _, line in ipairs(recipe_stats(recipe)) do
			lines[#lines + 1] = line
		end
	end
	local top = y + str_gui.INFO_IMAGE + 0.25
	fs[#fs + 1] = info_lines(x, top, w, needs_y - top - 0.1, lines)
	fs[#fs + 1] = str_gui.icon_rows(x, needs_y, w, {"Requires"}, rows)
	local status, color, buttons = ("Owned (%s credits)"):format(format_credits(recipe.price)), theme.equipped, nil
	if state == 1 then
		status = format_credits(recipe.price) .. " credits"
		color = resources.get_credits(player) >= recipe.price and theme.text or theme.danger
		buttons = {{"buy_recipe", "Buy Recipe", ACTION_BUTTON_W}}
	elseif state == 2 then
		status, color = "Locked - find every ingredient first", theme.muted
	end
	fs[#fs + 1] = str_gui.action_row(x, bottom, w, status, color, buttons)
	return table.concat(fs)
end

-- One button per section that has recipes shown, plus All
local function filter_buttons(player, name)
	local sections, seen = {}, {}
	for _, recipe in ipairs(visible_recipes(player)) do
		local key, title, icon = recipe_section(recipe)
		if not seen[key] then
			seen[key] = true
			sections[#sections + 1] = {key = key, title = title, icon = icon,
				text = key > 0 and key < 1000 and tostring(key) or nil, narrow = key > 0 and key < 1000}
		end
	end
	table.insert(sections, 1, {title = "All blueprints", text = "All"})
	local fs, names = {}, {}
	local x = TABLE_X
	for i, section in ipairs(sections) do
		local y = TABLE_Y
		local w = section.narrow and FILTER_TIER_W or FILTER_SIZE
		if i > 1 then
			x = x + FILTER_GAP
		end
		local btn = "rf_" .. (section.key or "all")
		names[i] = btn
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s;4]"):format(x, y, w, FILTER_SIZE,
			section.key == recipe_filter[name] and "str_upgrades_tab_bg_sel.png" or "str_upgrades_tab_bg.png")
		if section.icon then
			local icon_y = section.text and y + 0.12 or y + (FILTER_SIZE - FILTER_ICON) / 2
			fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(x + (w - FILTER_ICON) / 2, icon_y,
				FILTER_ICON, FILTER_ICON, section.icon)
		end
		if section.text then
			local text_y = section.icon and y + 0.6 or y
			fs[#fs + 1] = str_gui.info_text(x, text_y, w, section.icon and 0.35 or FILTER_SIZE,
				"<b>" .. esc(section.text) .. "</b>", nil, "center")
		end
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;]tooltip[%s;%s]"):format(x, y, w, FILTER_SIZE, btn, btn,
			esc(section.title))
		x = x + w
	end
	local list = table.concat(names, ",")
	table.insert(fs, 1, ("style[%s;border=false;bgimg=%s;padding=0]style[%s;bgimg=%s]"):format(list, FILTER_CLEAR,
		list:gsub(",", ":hovered,") .. ":hovered", FILTER_HOVER))
	return table.concat(fs)
end

local function recipes_tab(player, name)
	local entries = recipe_entries(player, name)
	local picked = picked_id(entries, selected_item[name])
	local fs = {
		filter_buttons(player, name),
		grid(name, RECIPE_GRID_Y, RECIPE_GRID_H, entries, picked),
		str_gui.input_bg(INFO_X, RECIPE_GRID_Y, INFO_W, RECIPE_GRID_H),
	}
	if picked then
		fs[#fs + 1] = recipe_info(player, str_recipes.get(picked))
	else
		fs[#fs + 1] = str_gui.info_text(INFO_X + INFO_PAD, RECIPE_GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD, 0.6,
			"Find new minerals to see their recipes here.", str_gui.theme.muted)
	end
	return table.concat(fs)
end

local PAY_FIELD_W, PAY_BUTTON_W = 5, 2.5

local ENDING_FORM = "str_company:ending"
local ENDING_W, ENDING_H = 16, 9
local ENDING_BUTTON_W = 5
local ENDING_TEXT = "<global halign=center color=#e8e4d8><big><b>Congratulations!</b></big>\n\n"
	.. "You paid off a debt that no corporate overlord ever expected you to.\n"
	.. "You beat the system, and found one ending of the game!\n\n"
	.. "You can leave now, or continue playing."

-- Black screen; allow_close[false] and the open window also stop the player moving
local function show_ending(player)
	str_story.set_ending_debt_found(player)
	str_machine.set_muted(player, true)
	str_audio.sfx.stop_all_loops(player)
	str_audio.music.play(player, "ending")
	local x = (ENDING_W - 2 * ENDING_BUTTON_W - 0.4) / 2
	core.show_formspec(player:get_player_name(), ENDING_FORM, table.concat({
		"formspec_version[8]",
		("size[%g,%g]"):format(ENDING_W, ENDING_H),
		"bgcolor[#000000;both;#000000]",
		"allow_close[false]",
		("hypertext[1,1.5;%g,4.5;;%s]"):format(ENDING_W - 2, ENDING_TEXT),
		("button[%g,%g;%g,0.9;ending_continue;Continue playing]"):format(x, ENDING_H - 1.7, ENDING_BUTTON_W),
		("button[%g,%g;%g,0.9;ending_leave;Leave game]"):format(x + ENDING_BUTTON_W + 0.4, ENDING_H - 1.7, ENDING_BUTTON_W),
	}))
end

-- Shown by Leave Strata instead of the ending while the player is under a departure hold
local LETTER_FORM = "str_company:departure_letter"
local LETTER_W, LETTER_H = 12, 8
local LETTER_TEXT = table.concat({
	"Dear Miner,",
	"",
	"Thank you for your departure request. Your account is currently subject to a Departure Hold.",
	"",
	"Your request has been added to the queue for psychological evaluation. "
		.. "A Company-approved assessor will visit you within 10 to 96 months.",
	"",
	"Until then, please continue mining.",
	"",
	"Employee Wellbeing Office, Excelsior Deep Yield Group",
}, "\n")

local function show_letter(player)
	core.show_formspec(player:get_player_name(), LETTER_FORM, table.concat({
		str_gui.header(LETTER_W, LETTER_H, "Departure Request"),
		("hypertext[0.4,%g;%g,%g;;<global color=%s>%s]"):format(str_gui.CONTENT_Y, LETTER_W - 0.8,
			LETTER_H - str_gui.CONTENT_Y - 1.6, str_gui.theme.text, esc(LETTER_TEXT)),
		("button[%g,%g;3,%g;letter_close;Close]"):format((LETTER_W - 3) / 2, LETTER_H - 0.4 - BUTTON_H, BUTTON_H),
	}))
end

local SLOT_PITCH = 1.25
local SELL_SLOTS = 4
local CONS_INV_Y = HEIGHT - 0.4 - 1
local CONS_INV_LABEL_Y = CONS_INV_Y - 0.6
local CONS_SLOTS_Y = CONS_INV_LABEL_Y - 0.2 - 1
local CONS_SELL_Y = CONS_SLOTS_Y - 0.6
local CONS_GRID_H = CONS_SELL_Y - 0.2 - TABLE_Y
local KIND_TITLES = {fuel = "Fuel canisters", repair = "Repair kits", teleport = "Teleporters"}
local cons_message = {}

local function consumable_entries(player)
	local entries = {}
	for i, def in ipairs(str_consumables.available(player)) do
		entries[i] = {id = def.name, item = def.name, label = def.description, tooltip = def.description,
			status = format_credits(def.price)}
	end
	return entries
end

local function consumable_info(player, def)
	local theme = str_gui.theme
	local x, y, w = INFO_X + INFO_PAD, TABLE_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = TABLE_Y + CONS_GRID_H - INFO_PAD
	local lines = {def.info}
	if def.note then
		lines[#lines + 1] = def.note
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = {"Price", format_credits(def.price) .. " credits"}
	lines[#lines + 1] = {("%s carried"):format(KIND_TITLES[def.kind] or "Items"),
		("%d / %d"):format(str_consumables.held(player, def.kind), str_consumables.MAX_PER_KIND)}
	local top = y + str_gui.INFO_IMAGE + 0.25
	return table.concat({
		str_gui.info_title(x, y, w, {item = def.name}, info_heading(def.description)),
		info_lines(x, top, w, bottom - str_gui.ACTION_H - 0.2 - top, lines),
		str_gui.action_row(x, bottom, w, nil, nil, {{"buy_cons_1", "Buy 1"}, {"buy_cons_10", "Buy 10"}}),
	})
end

local function consumables_tab(player, name)
	local entries = consumable_entries(player)
	local picked = picked_id(entries, selected_item[name])
	local fs = {
		grid(name, TABLE_Y, CONS_GRID_H, entries, picked),
		str_gui.input_bg(INFO_X, TABLE_Y, INFO_W, CONS_GRID_H),
		picked and consumable_info(player, str_consumables.items[picked]) or "",
		"style_type[label;valign=center]",
	}
	fs[#fs + 1] = ("label[%g,%g;5,0.5;Sell area (50%% of value)]"):format(GRID_X, CONS_SELL_Y)
	local inv = str_consumables.sell_inventory_name(player)
	fs[#fs + 1] = ("list[detached:%s;sell;%g,%g;%d,1;0.25]"):format(inv, GRID_X, CONS_SLOTS_Y, SELL_SLOTS)
	fs[#fs + 1] = ("label[%g,%g;%g,0.5;Your hotbar]"):format(GRID_X, CONS_INV_LABEL_Y, GRID_W)
	fs[#fs + 1] = ("label[%g,%g;%g,0.5;%s]"):format(INFO_X, CONS_INV_LABEL_Y, INFO_W, esc(cons_message[name] or ""))
	local hotbar = str_hotbar.list(player, "vehicle")
	fs[#fs + 1] = ("list[current_player;%s;%g,%g;8,1;0.25]"):format(hotbar, GRID_X, CONS_INV_Y)
	fs[#fs + 1] = ("listring[detached:%s;sell]listring[current_player;%s]"):format(inv, hotbar)
	if str_consumables.sell_count(player) > 0 then
		local x = GRID_X + SELL_SLOTS * SLOT_PITCH + 0.3
		fs[#fs + 1] = ("button[%g,%g;3.2,1;sell_cons;Sell]"):format(x, CONS_SLOTS_Y)
		fs[#fs + 1] = ("label[%g,%g;%g,1;Sell value:\n%s credits]"):format(
			x + 3.5, CONS_SLOTS_Y, WIDTH - x - 3.9, esc(format_credits(str_consumables.sell_value(player))))
	end
	fs[#fs + 1] = "style_type[label;valign=top]"
	return table.concat(fs)
end

local function debt_tab(player, name)
	local debt = str_story.get_debt(player)
	local headline = debt > 0 and ("<big>%s credits</big>"):format(esc(format_credits(debt))) or "<big>Congrats!</big>"
	local fs = {
		("hypertext[%g,%g;%g,2.2;;<global halign=center color=%s><style color=%s>%s</style>\n%s]"):format(
			TABLE_X, TABLE_Y + 0.4, TABLE_W, str_gui.theme.text, DIM_TEXT,
			debt > 0 and "Debt remaining" or "Debt paid off", headline),
	}
	local pay_y = HEIGHT / 2 + 0.6
	local x = (WIDTH - (PAY_FIELD_W + 0.3 + PAY_BUTTON_W)) / 2
	fs[#fs + 1] = ("label[%g,%g;Amount to pay:]"):format(x, pay_y - 0.3)
	fs[#fs + 1] = str_gui.input_bg(x, pay_y, PAY_FIELD_W, BUTTON_H)
	fs[#fs + 1] = ("field[%g,%g;%g,%g;amount;;]"):format(x, pay_y, PAY_FIELD_W, BUTTON_H)
	fs[#fs + 1] = "field_close_on_enter[amount;false]"
	fs[#fs + 1] = ("button[%g,%g;%g,%g;pay;Pay]"):format(x + PAY_FIELD_W + 0.3, pay_y, PAY_BUTTON_W, BUTTON_H)
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(x, pay_y + BUTTON_H + 0.5, esc(debt_message[name] or ""))
	if debt <= 0 then
		fs[#fs + 1] = ("button[%g,%g;%g,%g;leave_strata;Leave Strata]"):format(
			(WIDTH - 4) / 2, pay_y + BUTTON_H + 1.3, 4, BUTTON_H)
	end
	return table.concat(fs)
end

local mod_storage = core.get_mod_storage()
local BUYBACK_MAX = 20
local BUYBACK_MARKUP = 1.02
local buyback_cache = {}
local buyback_message = {}

-- Most recent sale first: {item = name, count = units}
local function buyback_list(player)
	local name = player:get_player_name()
	if not buyback_cache[name] then
		local raw = mod_storage:get_string("buyback:" .. name)
		local data = raw ~= "" and core.parse_json(raw)
		buyback_cache[name] = type(data) == "table" and data or {}
	end
	return buyback_cache[name]
end

local function save_buyback(player)
	mod_storage:set_string("buyback:" .. player:get_player_name(), core.write_json(buyback_list(player)))
end

local function buyback_price(def)
	return math.floor(def.price * BUYBACK_MARKUP * 100 + 0.5) / 100
end

local function buyback_counts(player)
	local counts = {}
	for _, entry in ipairs(buyback_list(player)) do
		counts[entry.item] = entry.count
	end
	return counts
end

local function record_sale(player, item, count)
	local list = buyback_list(player)
	for i, entry in ipairs(list) do
		if entry.item == item then
			count = count + entry.count
			table.remove(list, i)
			break
		end
	end
	table.insert(list, 1, {item = item, count = count})
	while #list > BUYBACK_MAX do
		table.remove(list)
	end
	save_buyback(player)
end

-- Buys up to count units into storage; returns a result message
local function buy_back(player, item, count)
	local def = str_materials.get(item)
	local list = buyback_list(player)
	local entry_index
	for i, entry in ipairs(list) do
		if entry.item == item then
			entry_index = i
		end
	end
	if not def or not entry_index then
		return "Nothing to buy back."
	end
	local unit = buyback_price(def)
	local affordable = math.floor(resources.get_credits(player) / unit + 1e-6)
	local wanted = math.min(count, list[entry_index].count, affordable)
	if wanted <= 0 then
		return "Not enough credits."
	end
	local added = str_storage.add(player, item, wanted)
	if added <= 0 then
		return "Your storage is full."
	end
	resources.spend_credits(player, added * unit)
	list[entry_index].count = list[entry_index].count - added
	if list[entry_index].count <= 0 then
		table.remove(list, entry_index)
	end
	save_buyback(player)
	return ("Bought %d %s for %s credits."):format(added, def.description, format_credits(added * unit)), added
end

local function buyback_tab(player, name)
	local table_fs, list, selected = str_inventory.item_table(buyback_counts(player), {
		x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = TABLE_H, selected = selected_item[name],
		empty = "Nothing sold recently.", unit_price = buyback_price,
	})
	local detail = buyback_message[name] or "Select an item to buy it back."
	if not buyback_message[name] then
		for i, row in ipairs(list) do
			if i == selected then
				detail = ("%s: %s credits each, %d available"):format(
					row.def.description, format_credits(buyback_price(row.def)), row.count)
			end
		end
	end
	local fs = {
		table_fs,
		("label[%g,%g;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 0.4, esc(detail)),
	}
	if selected > 0 then
		fs[#fs + 1] = ("button[%g,%g;3,%g;buy_back_1;Buy 1]"):format(TABLE_X, BUTTON_Y, BUTTON_H)
		fs[#fs + 1] = ("button[%g,%g;3,%g;buy_back_10;Buy 10]"):format(TABLE_X + 3.2, BUTTON_Y, BUTTON_H)
		fs[#fs + 1] = ("button[%g,%g;3,%g;buy_back_100;Buy 100]"):format(TABLE_X + 6.4, BUTTON_Y, BUTTON_H)
	end
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, HEIGHT - 0.45,
		esc(("Price is the sale price + %d%%. Purchases are delivered to your storage."):format(math.floor((BUYBACK_MARKUP - 1) * 100 + 0.5))))
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local tab = selected_tab[name] or DEFAULT_TAB
	local tabs, title = {}, ""
	for i, def in ipairs(TABS) do
		tabs[i] = {id = def.id, label = def.title}
		if def.id == tab then
			title = def.title
		end
	end
	local credits = resources.get_credits(player)
	local change = math.floor((credits - (visit_start[name] or credits)) * 100 + 0.5) / 100
	local change_text = ""
	if change ~= 0 then
		change_text = (" <style color=%s>(%s%s)</style>"):format(change > 0 and GAIN_COLOR or str_gui.theme.danger,
			change > 0 and "+" or "-", esc(format_credits(math.abs(change))))
	end
	local fs = {
		str_gui.header(WIDTH, HEIGHT, "Company Shop - " .. title),
		("hypertext[%g,0.25;7,0.5;;<global halign=right color=%s>Credits: %s%s]"):format(
			WIDTH - 7.4, str_gui.theme.text, esc(format_credits(credits)), change_text),
		str_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_W, h = TAB_H, selected_scale = 1, spacing = 0,
			tabs = tabs, selected = tab, prefix = "co_",
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
		}),
	}
	if tab == "sell" then
		fs[#fs + 1] = sell_tab(player, name)
	elseif tab == "buyback" then
		fs[#fs + 1] = buyback_tab(player, name)
	elseif tab == "consumables" then
		fs[#fs + 1] = consumables_tab(player, name)
	elseif tab == "debt" then
		fs[#fs + 1] = debt_tab(player, name)
	else
		fs[#fs + 1] = recipes_tab(player, name)
	end
	return table.concat(fs)
end

local function refresh(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

function str_company.show(player)
	visit_start[player:get_player_name()] = resources.get_credits(player)
	refresh(player)
end

-- Sells up to count units of an item at its list price
local function sell(player, item, count, store)
	local def = str_materials.get(item)
	local removed = def and store.remove(player, item, count) or 0
	if removed > 0 then
		resources.add_credits(player, removed * def.price)
		str_transmissions.count_relic(player:get_player_name(), item, "sold", removed)
		record_sale(player, item, removed)
	end
	return removed
end

local function pay_debt(player, text)
	local amount = str_story.parse_amount(text)
	if not amount then
		return "Enter an amount, such as 250 or 1,000.50."
	end
	local paid = math.min(amount, str_story.get_debt(player))
	if paid <= 0 then
		return "You owe nothing."
	end
	if not resources.spend_credits(player, paid) then
		return ("You only have %s credits."):format(format_credits(resources.get_credits(player)))
	end
	str_story.pay_debt(player, paid)
	return ("Paid %s credits."):format(format_credits(paid))
end

-- Tile entries of the grid tabs, rebuilt to read clicks
local TAB_ENTRIES = {
	sell = function(player, name) return sell_entries(player, name) end,
	recipes = function(player, name) return recipe_entries(player, name) end,
	consumables = function(player) return consumable_entries(player) end,
}

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	local current = selected_tab[name] or DEFAULT_TAB
	local scroll = str_gui.tile_scroll(fields, GRID_NAME)
	if scroll then
		grid_scroll[name] = grid_scroll[name] or {}
		grid_scroll[name][current] = scroll
	end
	if fields.quit then
		str_consumables.return_items(player)
		return
	end
	local entries = TAB_ENTRIES[current] and TAB_ENTRIES[current](player, name)
	local clicked = entries and str_gui.tile_clicked(fields, GRID_NAME, entries)
	local picked = entries and picked_id(entries, selected_item[name])
	local tab = str_gui.tab_clicked(fields, "co_")
	if tab then
		str_consumables.return_items(player)
		cons_message[name] = nil
		selected_tab[name], selected_item[name], debt_message[name], buyback_message[name] = tab, nil, nil, nil
	elseif clicked then
		selected_item[name] = clicked
	elseif current == "recipes" and str_gui.tab_clicked(fields, "rf_") then
		local filter = str_gui.tab_clicked(fields, "rf_")
		recipe_filter[name] = tonumber(filter)
		selected_item[name] = nil
		if grid_scroll[name] then
			grid_scroll[name].recipes = nil
		end
	elseif fields.leave_strata and str_story.get_debt(player) <= 0 then
		if str_story.get_departure_hold(player) then
			show_letter(player)
		else
			show_ending(player)
		end
		return
	elseif fields.pay or fields.key_enter_field == "amount" then
		debt_message[name] = pay_debt(player, fields.amount)
	elseif (fields.buy_back_1 or fields.buy_back_10 or fields.buy_back_100) and selected_item[name] then
		local message, added = buy_back(player, selected_item[name],
			fields.buy_back_100 and 100 or fields.buy_back_10 and 10 or 1)
		buyback_message[name] = message
		if added then
			play_register(player)
		end
	elseif fields.sell_src_cargo or fields.sell_src_storage then
		sell_source[name] = fields.sell_src_cargo and "cargo" or "storage"
		selected_item[name] = nil
		if grid_scroll[name] then
			grid_scroll[name].sell = nil
		end
	elseif (fields.sell_one or fields.sell_stack) and current == "sell" and picked then
		local store = current_source(name).store()
		selected_item[name] = picked
		if sell(player, picked, fields.sell_one and 1 or store.get(player)[picked] or 0, store) > 0 then
			play_register(player)
		end
	elseif fields.sell_all or fields.sell_no_uses then
		local store = current_source(name).store()
		local sold = 0
		for item, count in pairs(store.get(player)) do
			local def = str_materials.get(item)
			if fields.sell_all or def and has_no_uses(def) then
				sold = sold + sell(player, item, count, store)
			end
		end
		if sold > 0 then
			play_register(player)
		end
	elseif fields.buy_recipe and current == "recipes" and picked then
		local recipe = str_recipes.get(picked)
		if recipe and str_recipes.can_buy(player, recipe.name) and resources.spend_credits(player, recipe.price) then
			local index = 1
			for i, entry in ipairs(visible_recipes(player, recipe_filter[name])) do
				if entry.name == recipe.name then
					index = i
				end
			end
			str_recipes.unlock(player, recipe.name)
			play_register(player)
			-- The bought recipe moves to the owned end of its section; select what now takes its place
			local list = visible_recipes(player, recipe_filter[name])
			local next_recipe = list[math.min(index, #list)]
			selected_item[name] = next_recipe and next_recipe.name
		end
	elseif (fields.buy_cons_1 or fields.buy_cons_10) and current == "consumables" and picked then
		selected_item[name] = picked
		local bought, message = str_consumables.buy(player, picked, fields.buy_cons_10 and 10 or 1)
		cons_message[name] = message
		if bought > 0 then
			play_register(player)
		end
	elseif fields.sell_cons then
		local value = str_consumables.sell(player)
		cons_message[name] = value > 0 and ("Sold for %s credits."):format(format_credits(value)) or nil
		if value > 0 then
			play_register(player)
		end
	elseif current == "buyback" and fields.items then
		local event = core.explode_table_event(fields.items)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		local row = str_inventory.rows(buyback_counts(player))[event.row]
		buyback_message[name] = nil
		selected_item[name] = row and row.def.name
	else
		return
	end
	refresh(player)
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == LETTER_FORM and fields.letter_close then
		core.close_formspec(player:get_player_name(), LETTER_FORM)
	end
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= ENDING_FORM then
		return
	end
	local name = player:get_player_name()
	if fields.ending_continue then
		str_audio.music.stop(player)
		str_machine.set_muted(player, false)
		core.close_formspec(name, ENDING_FORM)
	elseif fields.ending_leave then
		core.disconnect_player(name, "You paid off your debt. Thanks for playing!")
	elseif fields.quit then
		show_ending(player)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_tab[name], selected_item[name], debt_message[name], cons_message[name] = nil, nil, nil, nil
	sell_source[name], buyback_cache[name], buyback_message[name], visit_start[name] = nil, nil, nil, nil
	grid_scroll[name], recipe_filter[name] = nil, nil
end)

str_consumables.register_on_sell_change(function(player)
	if selected_tab[player:get_player_name()] == "consumables" then
		refresh(player)
	end
end)
