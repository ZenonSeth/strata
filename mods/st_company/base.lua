local FORMNAME = "st_company:main"
local WIDTH, HEIGHT = 13, 10.5
local TAB_W, TAB_H = 2.2, 0.8
local TAB_X = 0.4
local TAB_Y = -TAB_H

local TABS = {
	{id = "recipes", title = "Buy"},
	{id = "sell", title = "Sell"},
	{id = "debt", title = "Debt"},
}
local DEFAULT_TAB = "sell"

local TABLE_X, TABLE_W = 0.4, WIDTH - 0.8
local TABLE_Y = st_gui.CONTENT_Y
local TABLE_H = HEIGHT - TABLE_Y - 2.8
local BUTTON_Y = TABLE_Y + TABLE_H + 0.8
local BUTTON_H = 0.8

local esc = core.formspec_escape
local num = st_inventory.num
local resources = st_player_resources
local format_credits = resources.format_credits

local selected_tab = {}
local selected_item = {}
local debt_message = {}

local function sell_tab(player, name)
	local table_fs, list, selected = st_inventory.cargo_table(player, {
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
for _, category in ipairs(st_machine_data.upgrades) do
	category_titles[category.id] = category.title
end

-- Icon cell value 1 is a smelter recipe (paper), 2 an upgrade (arrow)
local RECIPE_COLUMNS = {
	{title = "", spec = "image,align=center,padding=0.3,width=1.5,1=st_company_recipe.png,2=st_company_upgrade.png"},
	{title = "Recipe", spec = "text,width=24,padding=0.3"},
	{title = "Price", spec = "text,width=9,padding=0.3,tooltip=Price in credits"},
}

-- "2 Copper ore + 1 Coal"; inputs the player has not found yet show as ???
local function ingredients_text(player, recipe)
	local parts = {}
	for input, amount in pairs(recipe.from) do
		local label = st_recipes.has_found(player, input) and st_materials.get(input).description or "???"
		parts[#parts + 1] = amount .. " " .. label
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

-- Recipes with at least one found ingredient: buyable first, then locked, then owned (as in the table)
local function visible_recipes(player)
	local buyable, locked, owned = {}, {}, {}
	for _, recipe in ipairs(st_recipes.list) do
		if st_recipes.has(player, recipe.name) then
			owned[#owned + 1] = recipe
		elseif st_recipes.is_available(player, recipe.name) then
			buyable[#buyable + 1] = recipe
		elseif st_recipes.has_progress(player, recipe.name) then
			locked[#locked + 1] = recipe
		end
	end
	local order = {}
	for i, recipe in ipairs(st_recipes.list) do
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
	for _, list in ipairs({locked, owned}) do
		for _, recipe in ipairs(list) do
			buyable[#buyable + 1] = recipe
		end
	end
	return buyable
end

local function recipe_table(player, selected_name)
	local rows, selected = {}, 0
	for i, recipe in ipairs(visible_recipes(player)) do
		local owned = st_recipes.has(player, recipe.name)
		local available = st_recipes.is_available(player, recipe.name)
		rows[i] = {
			color = (available and not owned) and st_gui.theme.text or st_gui.theme.muted,
			cells = {
				recipe.kind == "material" and "1" or "2",
				recipe.description,
				owned and "Owned" or (available and format_credits(recipe.price) or "Locked"),
			},
		}
		if recipe.name == selected_name then
			selected = i
		end
	end
	return st_gui.list_table({
		x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = BUY_TABLE_H, name = "recipes",
		columns = RECIPE_COLUMNS, rows = rows, selected = selected,
	})
end

local function recipes_tab(player, name)
	local recipe = st_recipes.get(selected_item[name] or "")
	local fs = {recipe_table(player, selected_item[name])}
	local legend_y = TABLE_Y + BUY_TABLE_H + 0.15
	for i, key in ipairs({"recipe", "upgrade"}) do
		local x = TABLE_X + (i - 1) * LEGEND_STEP
		fs[#fs + 1] = ("image[%g,%g;%g,%g;st_company_%s.png]"):format(x, legend_y, LEGEND_ICON, LEGEND_ICON, key)
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(x + LEGEND_ICON + 0.15, legend_y + LEGEND_ICON / 2,
			key == "recipe" and "= Recipe" or "= Upgrade")
	end
	local lines = {"Select a recipe to see its details."}
	if recipe then
		local cost
		if st_recipes.has(player, recipe.name) then
			cost = "Owned"
		elseif st_recipes.is_available(player, recipe.name) then
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
				TABLE_X, y - 0.2, TABLE_W, st_gui.theme.text, DIM_TEXT, esc(line[1]), esc(line[2]))
		else
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, y, esc(line))
		end
	end
	if recipe and st_recipes.can_buy(player, recipe.name) then
		fs[#fs + 1] = ("button[%g,%g;3.5,%g;buy_recipe;Buy Recipe]"):format(
			WIDTH - TABLE_X - 3.5, HEIGHT - 0.4 - BUTTON_H, BUTTON_H)
	end
	return table.concat(fs)
end

local PAY_FIELD_W, PAY_BUTTON_W = 5, 2.5

local ENDING_FORM = "st_company:ending"
local ENDING_W, ENDING_H = 16, 9
local ENDING_BUTTON_W = 5
local ENDING_TEXT = "<global halign=center color=#e8e4d8><big><b>Congratulations!</b></big>\n\n"
	.. "You paid off a debt that no corporate overlord ever expected you to.\n"
	.. "You beat the system, and found one ending of the game!\n\n"
	.. "You can leave now, or continue playing."

-- Black screen; allow_close[false] and the open window also stop the player moving
local function show_ending(player)
	st_story.set_ending_debt_found(player)
	st_machine.set_muted(player, true)
	st_audio.sfx.stop_all_loops(player)
	st_audio.music.play(player, "ending")
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

local function debt_tab(player, name)
	local debt = st_story.get_debt(player)
	local headline = debt > 0 and ("<big>%s credits</big>"):format(esc(format_credits(debt))) or "<big>Congrats!</big>"
	local fs = {
		("hypertext[%g,%g;%g,2.2;;<global halign=center color=%s><style color=%s>%s</style>\n%s]"):format(
			TABLE_X, TABLE_Y + 0.4, TABLE_W, st_gui.theme.text, DIM_TEXT,
			debt > 0 and "Debt remaining" or "Debt paid off", headline),
	}
	local pay_y = HEIGHT / 2 + 0.6
	local x = (WIDTH - (PAY_FIELD_W + 0.3 + PAY_BUTTON_W)) / 2
	fs[#fs + 1] = ("label[%g,%g;Amount to pay:]"):format(x, pay_y - 0.3)
	fs[#fs + 1] = st_gui.input_bg(x, pay_y, PAY_FIELD_W, BUTTON_H)
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
		st_gui.header(WIDTH, HEIGHT, "Company Shop - " .. title),
		("hypertext[%g,0.25;5,0.5;;<global halign=right color=%s>Credits: %s]"):format(
			WIDTH - 5.4, st_gui.theme.text, esc(format_credits(resources.get_credits(player)))),
		st_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_W, h = TAB_H, selected_scale = 1, spacing = 0,
			tabs = tabs, selected = tab, prefix = "co_",
			bg = "st_upgrades_tab_bg.png", bg_selected = "st_upgrades_tab_bg_sel.png",
		}),
	}
	if tab == "sell" then
		fs[#fs + 1] = sell_tab(player, name)
	elseif tab == "debt" then
		fs[#fs + 1] = debt_tab(player, name)
	else
		fs[#fs + 1] = recipes_tab(player, name)
	end
	return table.concat(fs)
end

function st_company.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

-- Sells up to count units of an item at its list price
local function sell(player, item, count)
	local def = st_materials.get(item)
	local removed = def and st_machine.cargo.remove(player, item, count) or 0
	if removed > 0 then
		resources.add_credits(player, removed * def.price)
	end
end

local function pay_debt(player, text)
	local amount = st_story.parse_amount(text)
	if not amount then
		return "Enter an amount, such as 250 or 1,000.50."
	end
	local paid = math.min(amount, st_story.get_debt(player))
	if paid <= 0 then
		return "You owe nothing."
	end
	if not resources.spend_credits(player, paid) then
		return ("You only have %s credits."):format(format_credits(resources.get_credits(player)))
	end
	st_story.pay_debt(player, paid)
	return ("Paid %s credits."):format(format_credits(paid))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local name = player:get_player_name()
	local tab = st_gui.tab_clicked(fields, "co_")
	if tab then
		selected_tab[name], selected_item[name], debt_message[name] = tab, nil, nil
	elseif fields.leave_strata and st_story.get_debt(player) <= 0 then
		show_ending(player)
		return
	elseif fields.pay or fields.key_enter_field == "amount" then
		debt_message[name] = pay_debt(player, fields.amount)
	elseif fields.sell_one and selected_item[name] then
		sell(player, selected_item[name], 1)
	elseif fields.sell_stack and selected_item[name] then
		sell(player, selected_item[name], st_machine.cargo.get(player)[selected_item[name]] or 0)
	elseif fields.sell_all then
		for item, count in pairs(st_machine.cargo.get(player)) do
			sell(player, item, count)
		end
	elseif fields.buy_recipe and selected_item[name] then
		local recipe = st_recipes.get(selected_item[name])
		if recipe and st_recipes.can_buy(player, recipe.name) and resources.spend_credits(player, recipe.price) then
			local index = 1
			for i, entry in ipairs(visible_recipes(player)) do
				if entry.name == recipe.name then
					index = i
				end
			end
			st_recipes.unlock(player, recipe.name)
			-- The bought recipe moves to the owned end; keep the row, so the view does not jump
			local list = visible_recipes(player)
			local next_recipe = list[math.min(index, #list)]
			selected_item[name] = next_recipe and next_recipe.name
		end
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
		local row = st_inventory.cargo_rows(player)[event.row]
		selected_item[name] = row and row.def.name
	end
	st_company.show(player)
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= ENDING_FORM then
		return
	end
	local name = player:get_player_name()
	if fields.ending_continue then
		st_audio.music.stop(player)
		st_machine.set_muted(player, false)
		core.close_formspec(name, ENDING_FORM)
	elseif fields.ending_leave then
		core.disconnect_player(name, "You paid off your debt. Thanks for playing!")
	elseif fields.quit then
		show_ending(player)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_tab[name], selected_item[name], debt_message[name] = nil, nil, nil
end)
