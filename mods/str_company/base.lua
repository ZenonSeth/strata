local FORMNAME = "str_company:main"
local WIDTH, HEIGHT = 13, 10.5
local TAB_W, TAB_H = 2.2, 0.8
local TAB_X = 0.4
local TAB_Y = -TAB_H

local TABS = {
	{id = "sell", title = "Sell"},
	{id = "recipes", title = "Blueprints"},
	{id = "consumables", title = "Consumables"},
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

local selected_tab = {}
local selected_item = {}
local debt_message = {}

local function sell_tab(player, name)
	local table_fs, list, selected = str_inventory.cargo_table(player, {
		x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = TABLE_H, selected = selected_item[name],
	})
	local detail = "Select an item to sell it."
	local hold_value = 0
	for i, row in ipairs(list) do
		hold_value = hold_value + row.count * row.def.price
		if i == selected then
			detail = ("%s: %s credits each, %d held"):format(row.def.description, format_credits(row.def.price), row.count)
		end
	end
	local fs = {
		table_fs,
		("label[%g,%g;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 0.4, esc(detail)),
	}
	local x = TABLE_X
	if selected > 0 then
		fs[#fs + 1] = ("button[%g,%g;3,%g;sell_one;Sell 1]"):format(x, BUTTON_Y, BUTTON_H)
		fs[#fs + 1] = ("button[%g,%g;3,%g;sell_stack;Sell Stack]"):format(x + 3.2, BUTTON_Y, BUTTON_H)
	end
	if #list > 0 then
		fs[#fs + 1] = ("button[%g,%g;4,%g;sell_all;Sell Everything]"):format(x + 6.4, BUTTON_Y, BUTTON_H)
	end
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, HEIGHT - 0.45,
		esc(("Hold value: %s credits"):format(format_credits(hold_value))))
	return table.concat(fs)
end

local LEGEND_STEP, LEGEND_ICON = 2.6, 0.4
local BUY_TABLE_H = 4.9
local DIM_TEXT = "#b0aa9e"
local INFO_Y, INFO_STEP = TABLE_Y + BUY_TABLE_H + 0.95, 0.5

local category_titles = {}
for _, category in ipairs(str_machine_data.upgrades) do
	category_titles[category.id] = category.title
end

-- Icon cell value 1 is a smelter recipe (paper), 2 an upgrade (arrow)
local RECIPE_COLUMNS = {
	{title = "", spec = "image,align=center,padding=0.3,width=1.5,1=str_company_recipe.png,2=str_company_upgrade.png"},
	{title = "Recipe", spec = "text,width=24,padding=0.3"},
	{title = "Price", spec = "text,width=9,padding=0.3,tooltip=Price in credits"},
}

-- "2 Copper ore + 1 Coal"; inputs the player has not found yet show as ???
local function ingredients_text(player, recipe)
	local parts = {}
	for input, amount in pairs(recipe.from) do
		local label = str_recipes.has_found(player, input) and str_materials.get(input).description or "???"
		parts[#parts + 1] = amount .. " " .. label
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

local SPACER = {spacer = true}

-- Recipes with at least one found ingredient: buyable first, then locked, then owned (as in the table)
local function visible_recipes(player)
	local buyable, locked, owned = {}, {}, {}
	for _, recipe in ipairs(str_recipes.list) do
		if str_recipes.has(player, recipe.name) then
			owned[#owned + 1] = recipe
		elseif str_recipes.is_available(player, recipe.name) then
			buyable[#buyable + 1] = recipe
		elseif str_recipes.has_progress(player, recipe.name) then
			locked[#locked + 1] = recipe
		end
	end
	local order = {}
	for i, recipe in ipairs(str_recipes.list) do
		order[recipe.name] = i
	end
	for _, list in ipairs({buyable, locked}) do
		table.sort(list, function(a, b)
			if a.price ~= b.price then
				return a.price < b.price
			end
			return order[a.name] < order[b.name]
		end)
	end
	for _, recipe in ipairs(locked) do
		buyable[#buyable + 1] = recipe
	end
	if #owned > 0 and #buyable > 0 then
		buyable[#buyable + 1] = SPACER
	end
	for _, recipe in ipairs(owned) do
		buyable[#buyable + 1] = recipe
	end
	return buyable
end

local function recipe_table(player, selected_name)
	local rows, selected = {}, 0
	for i, recipe in ipairs(visible_recipes(player)) do
		local owned = str_recipes.has(player, recipe.name)
		local available = str_recipes.is_available(player, recipe.name)
		rows[i] = recipe.spacer and {cells = {"", "", ""}} or {
			color = (available and not owned) and str_gui.theme.text or str_gui.theme.muted,
			cells = {
				recipe.kind == "material" and "1" or "2",
				recipe.description,
				owned and "Owned" or (available and format_credits(recipe.price) or "Locked"),
			},
		}
		if not recipe.spacer and recipe.name == selected_name then
			selected = i
		end
	end
	return str_gui.list_table({
		x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = BUY_TABLE_H, name = "recipes",
		columns = RECIPE_COLUMNS, rows = rows, selected = selected,
	})
end

local STATS_X_OFFSET, STATS_LINE_H = 7.2, 0.45

local function find_level(recipe)
	for _, level in ipairs(str_machine_data.get_upgrade(recipe.kind).levels) do
		if str_recipes.level_recipe(recipe.kind, level.name) == recipe.name then
			return level
		end
	end
end

-- Same stat lines as the inventory's Equipment tab
local function stats_box(recipe, y)
	local level, category = find_level(recipe), str_machine_data.get_upgrade(recipe.kind)
	if not level then
		return ""
	end
	local lines = {{category.stat, category.stat.label}}
	for _, extra in ipairs(category.extra or {}) do
		lines[#lines + 1] = {extra, extra.label}
	end
	local x, w = TABLE_X + STATS_X_OFFSET, TABLE_W - STATS_X_OFFSET
	local fs = {
		("box[%g,%g;%g,%g;#1b1c1e]"):format(x, y, w, 0.4 + (#lines + 1) * STATS_LINE_H),
		("style_type[label;font_size=*1.15]label[%g,%g;%s]style_type[label;font_size=*1]"):format(
			x + 0.3, y + 0.4, esc(level.description)),
	}
	for j, line in ipairs(lines) do
		local text = str_machine_data.format_stat(line[1], level.stats[line[1].key])
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(x + 0.3, y + 0.4 + j * STATS_LINE_H,
			esc(core.colorize(str_gui.theme.muted, line[2] .. ":") .. " " .. text))
	end
	return table.concat(fs)
end

local function recipes_tab(player, name)
	local recipe = str_recipes.get(selected_item[name] or "")
	local fs = {recipe_table(player, selected_item[name])}
	local legend_y = TABLE_Y + BUY_TABLE_H + 0.15
	for i, key in ipairs({"recipe", "upgrade"}) do
		local x = TABLE_X + (i - 1) * LEGEND_STEP
		fs[#fs + 1] = ("image[%g,%g;%g,%g;str_company_%s.png]"):format(x, legend_y, LEGEND_ICON, LEGEND_ICON, key)
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(x + LEGEND_ICON + 0.15, legend_y + LEGEND_ICON / 2,
			key == "recipe" and "= Recipe" or "= Upgrade")
	end
	local lines = {"Select a recipe to see its details."}
	if recipe and recipe.kind ~= "material"
			and (str_recipes.has(player, recipe.name) or str_recipes.is_available(player, recipe.name)) then
		fs[#fs + 1] = stats_box(recipe, legend_y)
	end
	if recipe then
		local cost
		if str_recipes.has(player, recipe.name) then
			cost = "Owned"
		elseif str_recipes.is_available(player, recipe.name) then
			cost = format_credits(recipe.price) .. " credits"
		else
			cost = "Locked - find every ingredient first"
		end
		lines = {
			recipe.description,
			{"Type: ", recipe.kind == "material" and "Crafting recipe"
				or "Upgrade for " .. (category_titles[recipe.kind] or recipe.kind):lower()},
			{"Cost: ", cost},
			{"Requires: ", ingredients_text(player, recipe)},
		}
	end
	for i, line in ipairs(lines) do
		local y = INFO_Y + (i - 1) * INFO_STEP
		if type(line) == "table" then
			fs[#fs + 1] = ("hypertext[%g,%g;%g,0.5;;<global color=%s><style color=%s>%s</style>%s]"):format(
				TABLE_X, y - 0.2, STATS_X_OFFSET - 0.2, str_gui.theme.text, DIM_TEXT, esc(line[1]), esc(line[2]))
		else
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, y, esc(line))
		end
	end
	if recipe and str_recipes.can_buy(player, recipe.name) then
		fs[#fs + 1] = ("button[%g,%g;3.5,%g;buy_recipe;Buy Recipe]"):format(
			WIDTH - TABLE_X - 3.5, HEIGHT - 0.4 - BUTTON_H, BUTTON_H)
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

local CONS_COLUMNS = {
	{title = "Item", spec = "text,width=20,padding=0.3"},
	{title = "Price", spec = "text,width=9,padding=0.3,tooltip=Price in credits"},
}
local CONS_TABLE_H = 3.9
local CONS_BUY_Y = TABLE_Y + CONS_TABLE_H + 0.15
local CONS_SELL_Y = CONS_BUY_Y + 0.95
local CONS_SLOTS_Y = CONS_SELL_Y + 0.6
local SLOT_PITCH = 1.25
local SELL_SLOTS = 4
local INV_Y = HEIGHT - 1.4
local cons_message = {}

local function consumables_tab(player, name)
	local list = str_consumables.available(player)
	local rows, selected = {}, 0
	for i, def in ipairs(list) do
		rows[i] = {cells = {def.description, format_credits(def.price)}}
		if def.name == selected_item[name] then
			selected = i
		end
	end
	local fs = {
		str_gui.list_table({
			x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = CONS_TABLE_H, name = "consumables",
			columns = CONS_COLUMNS, rows = rows, selected = selected,
		}),
		"style_type[label;valign=center]",
	}
	if selected > 0 then
		fs[#fs + 1] = ("button[%g,%g;2.6,%g;buy_cons_1;Buy 1]"):format(TABLE_X, CONS_BUY_Y, BUTTON_H)
		fs[#fs + 1] = ("button[%g,%g;2.6,%g;buy_cons_10;Buy 10]"):format(TABLE_X + 2.8, CONS_BUY_Y, BUTTON_H)
	end
	local selected_def = str_consumables.items[selected_item[name] or ""]
	local lines = selected_def and {selected_def.description, selected_def.info, selected_def.note} or {}
	fs[#fs + 1] = "style_type[label;valign=top]"
	fs[#fs + 1] = ("label[%g,%g;%g,1.8;%s]"):format(
		TABLE_X + 5.8, CONS_BUY_Y, TABLE_W - 5.8, esc(table.concat(lines, "\n")))
	fs[#fs + 1] = "style_type[label;valign=center]"
	fs[#fs + 1] = ("label[%g,%g;5,0.5;Sell area (50%% of price)]"):format(TABLE_X, CONS_SELL_Y)
	local inv = str_consumables.sell_inventory_name(player)
	fs[#fs + 1] = ("list[detached:%s;sell;%g,%g;%d,1;0.25]"):format(inv, TABLE_X, CONS_SLOTS_Y, SELL_SLOTS)
	fs[#fs + 1] = ("label[%g,%g;%g,0.5;Your hotbar]"):format(TABLE_X, INV_Y - 0.7, TABLE_W)
	fs[#fs + 1] = ("label[%g,%g;%g,0.5;%s]"):format(TABLE_X + 5.8, INV_Y - 0.7, TABLE_W - 5.8, esc(cons_message[name] or ""))
	fs[#fs + 1] = ("list[current_player;main;%g,%g;8,1;0.25]"):format(TABLE_X, INV_Y)
	fs[#fs + 1] = ("listring[detached:%s;sell]listring[current_player;main]"):format(inv)
	if str_consumables.sell_count(player) > 0 then
		local x = TABLE_X + SELL_SLOTS * SLOT_PITCH + 0.3
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
	local fs = {
		str_gui.header(WIDTH, HEIGHT, "Company Shop - " .. title),
		("hypertext[%g,0.25;5,0.5;;<global halign=right color=%s>Credits: %s]"):format(
			WIDTH - 5.4, str_gui.theme.text, esc(format_credits(resources.get_credits(player)))),
		str_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_W, h = TAB_H, selected_scale = 1, spacing = 0,
			tabs = tabs, selected = tab, prefix = "co_",
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
		}),
	}
	if tab == "sell" then
		fs[#fs + 1] = sell_tab(player, name)
	elseif tab == "consumables" then
		fs[#fs + 1] = consumables_tab(player, name)
	elseif tab == "debt" then
		fs[#fs + 1] = debt_tab(player, name)
	else
		fs[#fs + 1] = recipes_tab(player, name)
	end
	return table.concat(fs)
end

function str_company.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

-- Sells up to count units of an item at its list price
local function sell(player, item, count)
	local def = str_materials.get(item)
	local removed = def and str_machine.cargo.remove(player, item, count) or 0
	if removed > 0 then
		resources.add_credits(player, removed * def.price)
		str_transmissions.count_relic(player:get_player_name(), item, "sold", removed)
	end
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

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	if fields.quit then
		str_consumables.return_items(player)
		return
	end
	local name = player:get_player_name()
	local tab = str_gui.tab_clicked(fields, "co_")
	if tab then
		str_consumables.return_items(player)
		cons_message[name] = nil
		selected_tab[name], selected_item[name], debt_message[name] = tab, nil, nil
	elseif fields.leave_strata and str_story.get_debt(player) <= 0 then
		show_ending(player)
		return
	elseif fields.pay or fields.key_enter_field == "amount" then
		debt_message[name] = pay_debt(player, fields.amount)
	elseif fields.sell_one and selected_item[name] then
		sell(player, selected_item[name], 1)
	elseif fields.sell_stack and selected_item[name] then
		sell(player, selected_item[name], str_machine.cargo.get(player)[selected_item[name]] or 0)
	elseif fields.sell_all then
		for item, count in pairs(str_machine.cargo.get(player)) do
			sell(player, item, count)
		end
	elseif fields.buy_recipe and selected_item[name] then
		local recipe = str_recipes.get(selected_item[name])
		if recipe and str_recipes.can_buy(player, recipe.name) and resources.spend_credits(player, recipe.price) then
			local index = 1
			for i, entry in ipairs(visible_recipes(player)) do
				if entry.name == recipe.name then
					index = i
				end
			end
			str_recipes.unlock(player, recipe.name)
			-- The bought recipe moves to the owned end; keep the row, so the view does not jump
			local list = visible_recipes(player)
			local next_recipe = list[math.min(index, #list)]
			if next_recipe and next_recipe.spacer then
				next_recipe = list[index + 1]
			end
			selected_item[name] = next_recipe and next_recipe.name
		end
	elseif (fields.buy_cons_1 or fields.buy_cons_10) and selected_item[name] then
		local _, message = str_consumables.buy(player, selected_item[name], fields.buy_cons_10 and 10 or 1)
		cons_message[name] = message
	elseif fields.sell_cons then
		local value = str_consumables.sell(player)
		cons_message[name] = value > 0 and ("Sold for %s credits."):format(format_credits(value)) or nil
	elseif fields.consumables then
		local event = core.explode_table_event(fields.consumables)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		local def = str_consumables.available(player)[event.row]
		selected_item[name] = def and def.name
	elseif fields.recipes then
		local event = core.explode_table_event(fields.recipes)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		local recipe = visible_recipes(player)[event.row]
		selected_item[name] = recipe and recipe.name
	else
		local event = core.explode_table_event(fields.items or "")
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		local row = str_inventory.cargo_rows(player)[event.row]
		selected_item[name] = row and row.def.name
	end
	str_company.show(player)
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
end)

str_consumables.register_on_sell_change(function(player)
	if selected_tab[player:get_player_name()] == "consumables" then
		str_company.show(player)
	end
end)
