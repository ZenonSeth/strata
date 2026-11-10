local FORMNAME = "st_company:main"
local WIDTH, HEIGHT = 13, 9
local TAB_SIZE = 0.8
local TAB_X = 0.4
local TAB_Y = -TAB_SIZE

-- Placeholder tab art until real icons exist
local TABS = {
	{id = "sell", title = "Sell", tooltip = "Sell", image = "[fill:32x32:#c8a040"},
	{id = "buy", title = "Buy", tooltip = "Buy", image = "[fill:32x32:#5a9a6a"},
}

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
		esc(("Credits: %s     Hold value: %s credits"):format(
			format_credits(resources.get_credits(player)), format_credits(hold_value))))
	return table.concat(fs)
end

local function buy_tab()
	return ("label[%g,%g;%s]"):format(TABLE_X + 0.3, TABLE_Y + 0.5, "Nothing for sale yet.")
end

local function build(player)
	local name = player:get_player_name()
	local tab = selected_tab[name] or TABS[1].id
	local tabs, title = {}, ""
	for i, def in ipairs(TABS) do
		tabs[i] = {id = def.id, image = def.image, tooltip = def.tooltip}
		if def.id == tab then
			title = def.title
		end
	end
	local fs = {
		st_gui.header(WIDTH, HEIGHT, "Company Contact - " .. title),
		st_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = tabs, selected = tab, prefix = "co_",
			bg = "st_upgrades_tab_bg.png", bg_selected = "st_upgrades_tab_bg_sel.png",
		}),
	}
	if tab == "sell" then
		fs[#fs + 1] = sell_tab(player, name)
	else
		fs[#fs + 1] = buy_tab()
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

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local name = player:get_player_name()
	local tab = st_gui.tab_clicked(fields, "co_")
	if tab then
		selected_tab[name] = tab
	elseif fields.sell_one and selected_item[name] then
		sell(player, selected_item[name], 1)
	elseif fields.sell_stack and selected_item[name] then
		sell(player, selected_item[name], st_machine.cargo.get(player)[selected_item[name]] or 0)
	elseif fields.sell_all then
		for item, count in pairs(st_machine.cargo.get(player)) do
			sell(player, item, count)
		end
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

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_tab[name], selected_item[name] = nil, nil
end)
