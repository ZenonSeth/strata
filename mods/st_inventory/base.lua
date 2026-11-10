local WIDTH, HEIGHT = 13, 9
local TAB_SIZE = 0.8
-- Tabs sit on the window's top edge, outside it
local TAB_X = 0.4
local TAB_Y = -TAB_SIZE
local CREDITS_W = 6.5

local TABS = {
	{id = "cargo", title = "Cargo Hold", tooltip = "Cargo Hold", image = "st_upgrades_tab_cargo.png"},
}

local TABLE_X, TABLE_W = 0.4, WIDTH - 0.8
local TABLE_Y = st_gui.CONTENT_Y
local TABLE_H = HEIGHT - TABLE_Y - 2.2

local esc = core.formspec_escape
local num = st_inventory.num
local format_credits = st_player_resources.format_credits

local selected_tab = {}
local selected_item = {}

local function inventory_tab(player, name)
	local table_fs, list, selected = st_inventory.cargo_table(player, {
		x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = TABLE_H, selected = selected_item[name],
	})
	local detail = "Select an item to see its per-unit values."
	local total_price, total_weight = 0, 0
	for i, row in ipairs(list) do
		total_price = total_price + row.count * row.def.price
		total_weight = total_weight + row.count * row.def.weight
		if i == selected then
			local def = row.def
			detail = ("%s: weight %s, volume %s, price %s each"):format(
				def.description, num(def.weight), num(def.volume), format_credits(def.price))
		end
	end
	local stats = st_machine.stats.get(player)
	local volume = st_machine.cargo.volume(player)
	local fs = {
		table_fs,
		("label[%g,%g;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 0.4, esc(detail)),
	}
	if selected > 0 then
		fs[#fs + 1] = ("button[%g,%g;3,0.8;discard;Discard 1]"):format(TABLE_X + TABLE_W - 3, TABLE_Y + TABLE_H + 0.05)
	end
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, HEIGHT - 0.9,
		esc(("Hold: %s / %s volume     Weight: %s     Value: %s credits"):format(
			num(volume), num(stats.cargo_capacity), num(total_weight), format_credits(total_price))))
	return table.concat(fs)
end

-- Right-aligned in the header bar; wide enough for 10-digit balances
local function credits_label(player)
	return table.concat({
		"style_type[label;halign=right;valign=center]",
		("label[%g,0;%g,%g;%s]"):format(WIDTH - 0.4 - CREDITS_W, CREDITS_W, st_gui.theme.header_height,
			esc("Credits: " .. format_credits(st_player_resources.get_credits(player)))),
		"style_type[label;halign=left;valign=top]",
	})
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
		st_gui.header(WIDTH, HEIGHT, title),
		st_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = tabs, selected = tab, prefix = "inv_",
			bg = "st_upgrades_tab_bg.png", bg_selected = "st_upgrades_tab_bg_sel.png",
		}),
		credits_label(player),
	}
	if tab == "cargo" then
		fs[#fs + 1] = inventory_tab(player, name)
	end
	return table.concat(fs)
end

local function refresh(player)
	player:set_inventory_formspec(build(player))
end

core.register_on_joinplayer(refresh)
st_machine.cargo.register_on_change(refresh)
st_player_resources.register_on_change(refresh)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then
		return
	end
	local name = player:get_player_name()
	local tab = st_gui.tab_clicked(fields, "inv_")
	if tab then
		selected_tab[name] = tab
		refresh(player)
		return
	end
	if fields.discard then
		if selected_item[name] then
			st_machine.cargo.remove(player, selected_item[name], 1)
		end
		return
	end
	local event = core.explode_table_event(fields.items or "")
	if event.type == "CHG" or event.type == "DCL" then
		local row = st_inventory.cargo_rows(player)[event.row]
		selected_item[name] = row and row.def.name
		refresh(player)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_tab[name], selected_item[name] = nil, nil
end)
