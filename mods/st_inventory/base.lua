local WIDTH, HEIGHT = 13, 10
local TAB_SIZE = 1
-- Tabs sit on the window's top edge, outside it
local TAB_X = 0.4
local TAB_Y = -TAB_SIZE
local CREDITS_W = 6.5

local TABS = {
	{id = "cargo", title = "Cargo Hold", tooltip = "Cargo Hold", image = "st_upgrades_tab_cargo.png"},
	{id = "equipment", title = "Equipment", tooltip = "Equipment", image = "st_upgrades_tab_hull.png"},
	{id = "danger", title = "Danger Zone", tooltip = "Danger Zone", image = "st_upgrades_tab_danger.png",
		visible = function(player) return st_mode.get(player) == "vehicle" end},
	{id = "settings", title = "Settings", tooltip = "Settings", image = "st_inventory_tab_settings.png", right = true},
}
table.insert(TABS, 3, {id = "transmissions", title = "Transmissions", tooltip = "Transmissions",
	image = "st_transmissions_tab.png", visible = st_transmissions.is_unlocked})

local TABLE_X, TABLE_W = 0.4, WIDTH - 0.8
local TABLE_Y = st_gui.CONTENT_Y
local TABLE_H = HEIGHT - TABLE_Y - 3.2

local esc = core.formspec_escape
local num = st_inventory.num
local format_credits = st_player_resources.format_credits
local muted = st_gui.theme.muted

local selected_tab = {}
local selected_item = {}
-- Players who clicked Self Destruct and have not confirmed yet
local armed = {}

local function tab_visible(player, def)
	return not def.visible or def.visible(player)
end

local function inventory_tab(player, name)
	local table_fs, list, selected = st_inventory.cargo_table(player, {
		x = TABLE_X, y = TABLE_Y, w = TABLE_W, h = TABLE_H, selected = selected_item[name],
	})
	local detail = core.colorize(muted, "Select an item to see its per-unit values.")
	local total_price, total_weight = 0, 0
	for i, row in ipairs(list) do
		total_price = total_price + row.count * row.def.price
		total_weight = total_weight + row.count * row.def.weight
		if i == selected then
			local def = row.def
			detail = ("%s%s %s%s %s%s %s%s"):format(
				def.description, core.colorize(muted, ": weight"), num(def.weight),
				core.colorize(muted, ", volume"), num(def.volume),
				core.colorize(muted, ", price"), format_credits(def.price), core.colorize(muted, " each"))
		end
	end
	local stats = st_machine.stats.get(player)
	local volume = st_machine.cargo.volume(player)
	local fs = {
		table_fs,
		"style_type[label;font_size=*1.25;halign=center;valign=center]",
		("label[%g,%g;%g,0.9;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 0.1, TABLE_W,
			esc(("Hold: %s / %s volume"):format(num(volume), num(stats.cargo_capacity)))),
		"style_type[label;font_size=*1;halign=left;valign=top]",
		("label[%g,%g;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 1.4, esc(detail)),
	}
	if selected > 0 then
		fs[#fs + 1] = ("button[%g,%g;3,0.8;discard;Discard 1]"):format(TABLE_X + TABLE_W - 3, TABLE_Y + TABLE_H + 1.05)
	end
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, HEIGHT - 0.9,
		esc(("%s %s     %s %s credits"):format(
			core.colorize(muted, "Total Weight:"), num(total_weight),
			core.colorize(muted, "Total Value:"), format_credits(total_price))))
	return table.concat(fs)
end

-- Grid order, left to right then down
local EQUIPMENT = {"hull", "engine", "drill", "thrusters", "tank", "cargo"}
local CELL_GAP, LINE_H = 0.3, 0.45
-- Row heights fit each row's longest stat list
local ROW_H = {1.75, 2.2, 1.3}
local CELL_W = (WIDTH - 0.8 - CELL_GAP) / 2

local function equipment_tab(player)
	local stats = st_machine.stats
	local fs = {}
	for i, id in ipairs(EQUIPMENT) do
		local category = st_machine_data.get_upgrade(id)
		local level = stats.get_level(player, id)
		local x = TABLE_X + ((i - 1) % 2) * (CELL_W + CELL_GAP)
		local row = math.ceil(i / 2)
		local y = st_gui.CONTENT_Y
		for r = 1, row - 1 do
			y = y + ROW_H[r] + CELL_GAP
		end
		fs[#fs + 1] = ("box[%g,%g;%g,%g;#1b1c1e]"):format(x, y, CELL_W, ROW_H[row])
		fs[#fs + 1] = ("style_type[label;font_size=*1.15]label[%g,%g;%s]style_type[label;font_size=*1]"):format(
			x + 0.3, y + 0.4, esc(level.description))
		local lines = {{category.stat, category.stat.label}}
		for _, extra in ipairs(category.extra or {}) do
			lines[#lines + 1] = {extra, extra.label}
		end
		for j, line in ipairs(lines) do
			local stat = line[1]
			local value = level.stats[stat.key]
			local text = st_machine_data.format_stat(stat, value)
			if category.condition and stat == category.stat then
				text = ("%d / %s"):format(math.ceil(stats.get_part_value(player, id)), text)
			end
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(x + 0.3, y + 0.4 + j * LINE_H,
				esc(core.colorize(muted, line[2] .. ":") .. " " .. text))
		end
	end
	local hotbar_y = HEIGHT - 1.4
	fs[#fs + 1] = ("label[%g,%g;%g,0.5;Hotbar]"):format(TABLE_X, hotbar_y - 0.7, TABLE_W)
	fs[#fs + 1] = ("list[current_player;main;%g,%g;8,1;0.25]"):format(TABLE_X, hotbar_y)
	return table.concat(fs)
end

local selected_transmission = {}

local function transmissions_tab(player, name)
	local items = st_transmissions.get(name)
	local rows = {}
	for i = #items, 1, -1 do
		rows[#rows + 1] = esc(("%s  %s"):format(os.date("%H:%M", items[i].time), items[i].text))
	end
	local selected = math.min(selected_transmission[name] or 1, #rows)
	local fs = {
		("textlist[%g,%g;%g,%g;transmission_list;%s;%d;false]"):format(
			TABLE_X, TABLE_Y, TABLE_W, TABLE_H, table.concat(rows, ","), selected),
	}
	local item = items[#items - selected + 1]
	if item then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 0.5,
			esc(core.colorize(muted, "Signal analysis: ") .. (item.analysis or "none")))
	end
	return table.concat(fs)
end

local VOLUME_STEP = 10
local SETTINGS_ROW_H = 1.3

local function settings_tab(player)
	local fs = {}
	for i, category in ipairs(st_audio.categories) do
		local y = st_gui.CONTENT_Y + 0.3 + (i - 1) * SETTINGS_ROW_H
		local on = st_audio.is_enabled(player, category.id)
		local pct = math.floor(st_audio.get_player_volume(player, category.id) * 100 + 0.5)
		local text = ("%d%%"):format(pct)
		fs[#fs + 1] = "style_type[label;valign=center]"
		fs[#fs + 1] = ("label[%g,%g;3,0.9;%s]"):format(TABLE_X, y, esc(category.title))
		fs[#fs + 1] = ("button[%g,%g;1.6,0.9;audio_%s_toggle;%s]"):format(3.6, y, category.id, on and "On" or "Off")
		fs[#fs + 1] = ("button[%g,%g;1.4,0.9;audio_%s_down;-%d]"):format(5.8, y, category.id, VOLUME_STEP)
		fs[#fs + 1] = ("style_type[label;halign=center]label[%g,%g;1.6,0.9;%s]style_type[label;halign=left]"):format(
			7.3, y, esc(on and text or core.colorize(muted, text)))
		fs[#fs + 1] = "style_type[label;valign=top]"
		fs[#fs + 1] = ("button[%g,%g;1.4,0.9;audio_%s_up;+%d]"):format(9.1, y, category.id, VOLUME_STEP)
	end
	return table.concat(fs)
end

local DANGER_BUTTON_W, DANGER_BUTTON_H = 5, 0.9

local function danger_tab(player, name)
	local y = st_gui.CONTENT_Y + 0.2
	local fs = {
		("style_type[label;textcolor=%s]"):format(muted),
		("label[%g,%g;%s]"):format(TABLE_X, y + 0.2,
			esc(core.colorize(muted, "Self destruct ") .. core.colorize(st_gui.theme.danger, "destroys the digger"))),
		("label[%g,%g;%s]"):format(TABLE_X, y + 0.7,
			esc("Cargo and equipped parts are lost, and you respawn at the workshop.")),
		("style_type[label;textcolor=%s]"):format(st_gui.theme.text),
		("button[%g,%g;%g,%g;self_destruct;Self Destruct]"):format(TABLE_X, y + 1.5, DANGER_BUTTON_W, DANGER_BUTTON_H),
	}
	if armed[name] then
		fs[#fs + 1] = "style[confirm_destruct:hovered;bgcolor=#d04030]"
		fs[#fs + 1] = ("button[%g,%g;%g,%g;confirm_destruct;Confirm Self Destruct]"):format(
			TABLE_X, y + 1.5 + DANGER_BUTTON_H + 0.3, DANGER_BUTTON_W, DANGER_BUTTON_H)
	end
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
	local tabs, right_tabs, title = {}, {}, nil
	for _, def in ipairs(TABS) do
		if tab_visible(player, def) then
			local list = def.right and right_tabs or tabs
			list[#list + 1] = {id = def.id, image = def.image, tooltip = def.tooltip}
			if def.id == tab then
				title = def.title
			end
		end
	end
	if not title then
		tab, title = TABS[1].id, TABS[1].title
	end
	local fs = {
		st_gui.header(WIDTH, HEIGHT, title),
		st_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = tabs, selected = tab, prefix = "inv_",
			bg = "st_upgrades_tab_bg.png", bg_selected = "st_upgrades_tab_bg_sel.png",
		}),
		-- Own prefix so its backing button does not clash with the left bar's
		st_gui.tab_bar({
			x = WIDTH - TAB_X - TAB_SIZE, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = right_tabs, selected = tab, prefix = "invr_",
			bg = "st_upgrades_tab_bg.png", bg_selected = "st_upgrades_tab_bg_sel.png",
		}),
		credits_label(player),
	}
	if tab == "cargo" then
		fs[#fs + 1] = inventory_tab(player, name)
	elseif tab == "equipment" then
		fs[#fs + 1] = equipment_tab(player)
	elseif tab == "transmissions" then
		fs[#fs + 1] = transmissions_tab(player, name)
	elseif tab == "settings" then
		fs[#fs + 1] = settings_tab(player)
	elseif tab == "danger" then
		fs[#fs + 1] = danger_tab(player, name)
	end
	return table.concat(fs)
end

local function refresh(player)
	player:set_inventory_formspec(build(player))
end

core.register_on_joinplayer(refresh)
st_mode.register_on_change(function(player)
	armed[player:get_player_name()] = nil
	refresh(player)
end)
st_machine.cargo.register_on_change(refresh)
st_machine.stats.register_on_change(refresh)
st_transmissions.register_on_change(refresh)
st_player_resources.register_on_change(refresh)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then
		return
	end
	local name = player:get_player_name()
	local tab = st_gui.tab_clicked(fields, "inv_") or st_gui.tab_clicked(fields, "invr_")
	if tab then
		selected_tab[name] = tab
		armed[name] = nil
		refresh(player)
		return
	end
	if fields.quit then
		-- The Danger Zone tab is never remembered: the inventory reopens on the default tab
		local reset = armed[name] or selected_tab[name] == "danger"
		armed[name] = nil
		if selected_tab[name] == "danger" then
			selected_tab[name] = nil
		end
		if reset then
			refresh(player)
		end
		return
	end
	if fields.self_destruct then
		armed[name] = st_mode.get(player) == "vehicle" or nil
		refresh(player)
		return
	end
	if fields.confirm_destruct then
		if armed[name] then
			armed[name] = nil
			refresh(player)
			st_machine.destroy(player)
		end
		return
	end
	for _, category in ipairs(st_audio.categories) do
		local id = category.id
		local step = (fields["audio_" .. id .. "_up"] and VOLUME_STEP) or (fields["audio_" .. id .. "_down"] and -VOLUME_STEP)
		if step then
			local pct = math.floor(st_audio.get_player_volume(player, id) * 100 + 0.5) + step
			st_audio.set_volume(player, id, math.max(0, math.min(100, pct)) / 100)
			refresh(player)
			return
		end
	end
	for _, category in ipairs(st_audio.categories) do
		local id = category.id
		if fields["audio_" .. id .. "_toggle"] then
			st_audio.set_enabled(player, id, not st_audio.is_enabled(player, id))
			refresh(player)
			return
		end
	end
	if fields.transmission_list then
		local event = core.explode_textlist_event(fields.transmission_list)
		if event.type == "CHG" or event.type == "DCL" then
			selected_transmission[name] = event.index
			refresh(player)
		end
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
	selected_tab[name], selected_item[name], armed[name] = nil, nil, nil
	selected_transmission[name] = nil
end)
