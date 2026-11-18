local volume_unit = str_utils.constants.volume_unit
local weight_unit = str_utils.constants.weight_unit
local WIDTH, HEIGHT = 13, 10
local TAB_SIZE = 1
-- Tabs sit on the window's top edge, outside it
local TAB_X = 0.4
local TAB_Y = -TAB_SIZE
local CREDITS_W = 6.5

local TABS = {
	{id = "cargo", title = "Cargo Hold", tooltip = "Cargo Hold", image = "str_upgrades_tab_cargo.png"},
	{id = "equipment", title = "Equipment", tooltip = "Equipment", image = "str_upgrades_tab_hull.png"},
	{id = "danger", title = "Danger Zone", tooltip = "Danger Zone", image = "str_upgrades_tab_danger.png",
		visible = function(player) return str_mode.get(player) == "vehicle" end},
	{id = "settings", title = "Settings", tooltip = "Settings", image = "str_inventory_tab_settings.png", right = true},
}
table.insert(TABS, 3, {id = "transmissions", title = "Transmissions", tooltip = "Transmissions",
	image = "str_transmissions_tab.png", visible = str_transmissions.is_unlocked})

str_inventory.WIDTH, str_inventory.HEIGHT = WIDTH, HEIGHT

-- def: id, title, tooltip, image, visible (optional fn(player)), after (tab id to follow),
-- build(player, name) -> formspec, on_fields(player, fields) -> true when handled, on_leave(name)
function str_inventory.register_tab(def)
	local at = #TABS + 1
	for i, tab in ipairs(TABS) do
		if tab.id == def.after then
			at = i + 1
		end
	end
	table.insert(TABS, at, def)
end

local TABLE_X, TABLE_W = 0.4, WIDTH - 0.8
local TABLE_Y = str_gui.CONTENT_Y
local TABLE_H = HEIGHT - TABLE_Y - 3.2

local esc = core.formspec_escape
local num = str_inventory.num
local format_credits = str_player_resources.format_credits
local muted = str_gui.theme.muted

local selected_tab = {}
local selected_item = {}
-- One-line result of the last Drop, shown in place of the item details
local message = {}
local drop_handler
local AMOUNTS = {1, 10, 50}
local AMOUNT_W, AMOUNT_GAP, AMOUNT_H, AMOUNT_LABEL_H = 1.1, 0.1, 0.8, 0.4

-- fn(player, item, count) -> units moved, reason when none did; Drop buttons call it
function str_inventory.set_drop_handler(fn)
	drop_handler = fn
end
-- Players who clicked Self Destruct and have not confirmed yet
local armed = {}

local function tab_visible(player, def)
	return not def.visible or def.visible(player)
end

local function inventory_tab(player, name)
	local table_fs, list, selected = str_inventory.cargo_table(player, {
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
				def.description, core.colorize(muted, ": weight"), num(def.weight) .. " " .. weight_unit,
				core.colorize(muted, ", volume"), num(def.volume) .. " " .. volume_unit,
				core.colorize(muted, ", price"), format_credits(def.price), core.colorize(muted, " each"))
		end
	end
	local stats = str_machine.stats.get(player)
	local volume = str_machine.cargo.volume(player)
	local fs = {
		table_fs,
		"style_type[label;font_size=*1.25;halign=center;valign=center]",
		("label[%g,%g;%g,0.9;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 0.1, TABLE_W,
			esc(("Hold: %s / %s %s"):format(num(volume), num(stats.cargo_capacity), volume_unit))),
		"style_type[label;font_size=*1;halign=left;valign=top]",
		("label[%g,%g;%s]"):format(TABLE_X, TABLE_Y + TABLE_H + 1.4, esc(message[name] or detail)),
	}
	if selected > 0 then
		local group_w = #AMOUNTS * AMOUNT_W + (#AMOUNTS - 1) * AMOUNT_GAP
		local buttons_x = TABLE_X + TABLE_W - group_w
		fs[#fs + 1] = "style_type[label;valign=center]"
		for row, action in ipairs({{id = "drop", label = "Drop"}, {id = "discard", label = "Discard"}}) do
			local label_y = TABLE_Y + TABLE_H + 0.15 + (row - 1) * (AMOUNT_LABEL_H + AMOUNT_H + 0.1)
			local y = label_y + AMOUNT_LABEL_H
			fs[#fs + 1] = ("label[%g,%g;%g,%g;%s]"):format(buttons_x, label_y, group_w, AMOUNT_LABEL_H, action.label)
			for i, amount in ipairs(AMOUNTS) do
				local field = action.id .. "_" .. amount
				if action.id == "discard" then
					fs[#fs + 1] = ("style[%s:hovered;bgcolor=#d04030]"):format(field)
				end
				fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%d]"):format(buttons_x + (i - 1) * (AMOUNT_W + AMOUNT_GAP), y,
					AMOUNT_W, AMOUNT_H, field, amount)
			end
		end
		fs[#fs + 1] = "style_type[label;valign=top]"
	end
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(TABLE_X, HEIGHT - 0.9,
		esc(("%s %s     %s %s credits"):format(
			core.colorize(muted, "Total Weight:"), num(total_weight) .. " " .. weight_unit,
			core.colorize(muted, "Total Value:"), format_credits(total_price))))
	return table.concat(fs)
end

-- Grid order, left to right then down
local EQUIPMENT = {"hull", "engine", "drill", "thrusters", "tank", "cargo"}
local CELL_GAP, LINE_H = 0.3, 0.45
-- Row heights fit each row's longest stat list
local ROW_H = {1.75, 2.2, 1.3}
local CELL_W = (WIDTH - 0.8 - CELL_GAP) / 2
local SLOT_ICON, SLOT_GAP, SLOT_BOTTOM = 0.7, 0.1, 0.25

-- Fitted hull upgrades, right-aligned so they end at right_x; view only
local function hull_slot_icons(player, right_x, y)
	local list = player:get_inventory():get_list(str_machine.hull_slots.LIST) or {}
	local fs = {}
	for i, stack in ipairs(list) do
		local x = right_x - (#list - i + 1) * SLOT_ICON - (#list - i) * SLOT_GAP
		fs[#fs + 1] = ("image[%g,%g;%g,%g;str_gui_slot.png]"):format(x, y, SLOT_ICON, SLOT_ICON)
		if not stack:is_empty() then
			fs[#fs + 1] = ("item_image[%g,%g;%g,%g;%s]"):format(x, y, SLOT_ICON, SLOT_ICON, stack:get_name())
			fs[#fs + 1] = ("tooltip[%g,%g;%g,%g;%s]"):format(x, y, SLOT_ICON, SLOT_ICON,
				esc(stack:get_description()))
		end
	end
	return table.concat(fs)
end

local function equipment_tab(player)
	local stats = str_machine.stats
	local fs = {}
	for i, id in ipairs(EQUIPMENT) do
		local category = str_machine_data.get_upgrade(id)
		local level = stats.get_level(player, id)
		local x = TABLE_X + ((i - 1) % 2) * (CELL_W + CELL_GAP)
		local row = math.ceil(i / 2)
		local y = str_gui.CONTENT_Y
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
			local text = str_machine_data.format_stat(stat, value)
			if category.condition and stat == category.stat then
				text = ("%d / %s"):format(math.ceil(stats.get_part_value(player, id)), text)
			end
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(x + 0.3, y + 0.4 + j * LINE_H,
				esc(core.colorize(muted, line[2] .. ":") .. " " .. text))
		end
		if id == "hull" then
			fs[#fs + 1] = hull_slot_icons(player, x + CELL_W - 0.3, y + ROW_H[row] - SLOT_ICON - SLOT_BOTTOM)
		end
	end
	local hotbar_y = HEIGHT - 1.4
	fs[#fs + 1] = ("label[%g,%g;%g,0.5;Hotbar]"):format(TABLE_X, hotbar_y - 0.7, TABLE_W)
	fs[#fs + 1] = ("list[current_player;main;%g,%g;8,1;0.25]"):format(TABLE_X, hotbar_y)
	return table.concat(fs)
end

-- Entries whose signal analysis is open: expanded_analysis[name][index]
local expanded_analysis = {}
local GLYPH_SIZE = 24
local LOG_LINK, LOG_LINK_HOVER, LOG_STAMP = "#e8b040", "#ffd878", "#a9abb0"
-- Room under the log for buttons
local LOG_H = HEIGHT - TABLE_Y - 1.6

local function hypertext_escape(text)
	return (text:gsub("[\\<>]", "\\%0"))
end

-- The row under the log: signal_row[name] = {kind = "decode" or "reply", index = log index}
local signal_row = {}
local decode_input, decode_result = {}, {}
local ROW_Y, ROW_H = HEIGHT - 1.4, 0.9
local REPLY_GAP = 0.2

local function decoded_line(revealed)
	local words = {}
	for i, word in ipairs(revealed) do
		words[i] = word ~= "" and word or ("<style color=%s>?</style>"):format(muted)
	end
	return "Decoded: " .. table.concat(words, " ")
end

local function signal_controls(name, items)
	local row = signal_row[name]
	local labelled = row and items[row.index] and not items[row.index].sent
	if labelled and row.kind == "reply" then
		local options = str_transmissions.reply_options(name, row.index)
		if options then
			local w = (TABLE_W - REPLY_GAP * (#options - 1)) / #options
			local fs = {}
			for i, option in ipairs(options) do
				local button = "reply_" .. i
				local x = TABLE_X + (i - 1) * (w + REPLY_GAP)
				if not option.enabled then
					fs[#fs + 1] = ("style[%s;textcolor=%s]"):format(button, muted)
					fs[#fs + 1] = ("tooltip[%s;Decode this signal first]"):format(button)
				end
				fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(x, ROW_Y, w, ROW_H, button,
					option.enabled and esc(option.label) or "???")
			end
			return table.concat(fs)
		end
	elseif labelled and row.kind == "decode" then
		local field_x, field_w, check_w = TABLE_X + 2, 5.6, 1.5
		local check_x = field_x + field_w + 0.2
		local result_x = check_x + check_w + 0.2
		return table.concat({
			"style_type[label;valign=center]",
			("label[%g,%g;1.8,%g;%s]"):format(TABLE_X, ROW_Y, ROW_H, esc("Signal " .. row.number)),
			("label[%g,%g;%g,%g;%s]"):format(result_x, ROW_Y, TABLE_X + TABLE_W - result_x, ROW_H,
				esc(core.colorize(muted, decode_result[name] or ""))),
			"style_type[label;valign=top]",
			str_gui.input_bg(field_x, ROW_Y, field_w, ROW_H),
			("field[%g,%g;%g,%g;decode_text;;%s]"):format(field_x, ROW_Y, field_w, ROW_H, esc(decode_input[name] or "")),
			"field_close_on_enter[decode_text;false]",
			("button[%g,%g;%g,%g;decode_check;Check]"):format(check_x, ROW_Y, check_w, ROW_H),
		})
	end
	return table.concat({
		"style_type[label;valign=center]",
		("label[%g,%g;%g,%g;%s]"):format(TABLE_X, ROW_Y, TABLE_W, ROW_H,
			esc(core.colorize(muted, "Decode a signal to type your reading of it."))),
		"style_type[label;valign=top]",
	})
end

local function transmissions_tab(player, name)
	local items = str_transmissions.get(name)
	local open = expanded_analysis[name] or {}
	local text_color = str_gui.theme.text
	local lines = {
		("<global margin=8 color=%s background=#00000055>"):format(text_color),
		("<tag name=action color=%s hovercolor=%s>"):format(LOG_LINK, LOG_LINK_HOVER),
	}
	local numbers, count = {}, 0
	for i, item in ipairs(items) do
		if not item.sent then
			count = count + 1
			numbers[i] = count
		end
	end
	for i = #items, 1, -1 do
		local item = items[i]
		local stamp = os.date("%H:%M", item.time)
		if item.sent then
			lines[#lines + 1] = ("<style color=%s>Sent  %s</style>"):format(LOG_STAMP, stamp)
			lines[#lines + 1] = hypertext_escape(item.sent)
		else
			lines[#lines + 1] = ("<style color=%s>Signal %d  %s</style>"):format(LOG_STAMP, numbers[i], stamp)
			lines[#lines + 1] = str_transmissions.markup(item.text, GLYPH_SIZE)
			local revealed = str_transmissions.revealed(name, i)
			if revealed and table.concat(revealed) ~= "" then
				lines[#lines + 1] = decoded_line(revealed)
			end
			local links = {("<action name=analysis_%d>[%s] Signal analysis</action>"):format(i, open[i] and "-" or "+")}
			if not str_transmissions.is_decoded(name, i) then
				links[#links + 1] = ("<action name=decode_%d>Decode</action>"):format(i)
			end
			if str_transmissions.reply_options(name, i) then
				links[#links + 1] = ("<action name=reply_%d>Reply</action>"):format(i)
			end
			lines[#lines + 1] = table.concat(links, "    ")
			if open[i] then
				lines[#lines + 1] = hypertext_escape(item.analysis or "none")
			end
		end
		lines[#lines + 1] = ""
	end
	local row = signal_row[name]
	if row then
		row.number = numbers[row.index]
	end
	return ("hypertext[%g,%g;%g,%g;transmission_log;%s]"):format(
		TABLE_X, TABLE_Y, TABLE_W, LOG_H, esc(table.concat(lines, "\n"))) .. signal_controls(name, items)
end

local VOLUME_STEP = 10
local SETTINGS_ROW_H = 1.3

local function settings_tab(player)
	local fs = {}
	for i, category in ipairs(str_audio.categories) do
		local y = str_gui.CONTENT_Y + 0.3 + (i - 1) * SETTINGS_ROW_H
		local on = str_audio.is_enabled(player, category.id)
		local pct = math.floor(str_audio.get_player_volume(player, category.id) * 100 + 0.5)
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
	local y = str_gui.CONTENT_Y + 0.2
	local fs = {
		("style_type[label;textcolor=%s]"):format(muted),
		("label[%g,%g;%s]"):format(TABLE_X, y + 0.2,
			esc(core.colorize(muted, "Self destruct ") .. core.colorize(str_gui.theme.danger, "destroys the digger"))),
		("label[%g,%g;%s]"):format(TABLE_X, y + 0.7,
			esc("Cargo and equipped parts are lost, and you respawn at the workshop.")),
		("style_type[label;textcolor=%s]"):format(str_gui.theme.text),
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
		("label[%g,0;%g,%g;%s]"):format(WIDTH - 0.4 - CREDITS_W, CREDITS_W, str_gui.theme.header_height,
			esc("Credits: " .. format_credits(str_player_resources.get_credits(player)))),
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
		str_gui.header(WIDTH, HEIGHT, title),
		str_gui.tab_bar({
			x = TAB_X, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = tabs, selected = tab, prefix = "inv_",
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
		}),
		-- Own prefix so its backing button does not clash with the left bar's
		str_gui.tab_bar({
			x = WIDTH - TAB_X - TAB_SIZE, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = right_tabs, selected = tab, prefix = "invr_",
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
		}),
		-- Shortcut, not a tab: nothing is ever selected
		str_gui.tab_bar({
			x = WIDTH - TAB_X - 2 * TAB_SIZE - 0.1, y = TAB_Y, w = TAB_SIZE, h = TAB_SIZE, selected_scale = 1,
			tabs = {{id = "manual", image = "str_manual_tab.png", tooltip = "Manual"}}, prefix = "invm_",
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
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
	else
		for _, def in ipairs(TABS) do
			if def.id == tab and def.build then
				fs[#fs + 1] = def.build(player, name)
			end
		end
	end
	return table.concat(fs)
end

local function refresh(player)
	player:set_inventory_formspec(build(player))
end

str_inventory.refresh = refresh

core.register_on_joinplayer(refresh)
str_mode.register_on_change(function(player)
	armed[player:get_player_name()] = nil
	refresh(player)
end)
str_machine.cargo.register_on_change(refresh)
str_machine.stats.register_on_change(refresh)
str_transmissions.register_on_change(refresh)
str_player_resources.register_on_change(refresh)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "" then
		return
	end
	local name = player:get_player_name()
	if str_gui.tab_clicked(fields, "invm_") then
		str_manual.show(name)
		return
	end
	local tab = str_gui.tab_clicked(fields, "inv_") or str_gui.tab_clicked(fields, "invr_")
	if tab then
		selected_tab[name] = tab
		message[name] = nil
		armed[name] = nil
		refresh(player)
		return
	end
	if fields.quit then
		-- The Danger Zone tab is never remembered: the inventory reopens on the default tab
		-- The decode row closes too, so its field does not grab the inventory key next time
		local reset = armed[name] or selected_tab[name] == "danger" or signal_row[name]
		armed[name], signal_row[name] = nil, nil
		if selected_tab[name] == "danger" then
			selected_tab[name] = nil
		end
		if reset then
			refresh(player)
		end
		return
	end
	for _, def in ipairs(TABS) do
		if def.on_fields and def.id == selected_tab[name] and def.on_fields(player, fields) then
			return
		end
	end
	if fields.self_destruct then
		armed[name] = str_mode.get(player) == "vehicle" or nil
		refresh(player)
		return
	end
	if fields.confirm_destruct then
		if armed[name] then
			armed[name] = nil
			refresh(player)
			str_machine.destroy(player)
		end
		return
	end
	for _, category in ipairs(str_audio.categories) do
		local id = category.id
		local step = (fields["audio_" .. id .. "_up"] and VOLUME_STEP) or (fields["audio_" .. id .. "_down"] and -VOLUME_STEP)
		if step then
			local pct = math.floor(str_audio.get_player_volume(player, id) * 100 + 0.5) + step
			str_audio.set_volume(player, id, math.max(0, math.min(100, pct)) / 100)
			refresh(player)
			return
		end
	end
	for _, category in ipairs(str_audio.categories) do
		local id = category.id
		if fields["audio_" .. id .. "_toggle"] then
			str_audio.set_enabled(player, id, not str_audio.is_enabled(player, id))
			refresh(player)
			return
		end
	end
	local analysis = (fields.transmission_log or ""):match("^action:analysis_(%d+)$")
	if analysis then
		local open = expanded_analysis[name] or {}
		open[tonumber(analysis)] = not open[tonumber(analysis)] or nil
		expanded_analysis[name] = open
		refresh(player)
		return
	end
	local kind, index = (fields.transmission_log or ""):match("^action:(%a+)_(%d+)$")
	if kind == "decode" or kind == "reply" then
		signal_row[name] = {kind = kind, index = tonumber(index)}
		decode_input[name], decode_result[name] = nil, nil
		refresh(player)
		return
	end
	local row = signal_row[name]
	if row and row.kind == "decode" and (fields.decode_check or fields.key_enter_field == "decode_text") then
		local text = fields.decode_text or ""
		local new = str_transmissions.decode(name, row.index, text)
		decode_input[name] = text
		if not str_transmissions.revealed(name, row.index) then
			decode_result[name] = "No words found"
		elseif str_transmissions.is_decoded(name, row.index) then
			decode_result[name] = "Fully decoded"
		else
			decode_result[name] = new == 0 and "No match" or ("%d new word%s"):format(new, new == 1 and "" or "s")
		end
		refresh(player)
		return
	end
	for i = 1, 3 do
		if row and row.kind == "reply" and fields["reply_" .. i] then
			if str_transmissions.reply(name, row.index, i) then
				signal_row[name] = nil
			end
			return
		end
	end
	local item = selected_item[name]
	for _, amount in ipairs(AMOUNTS) do
		if item and fields["discard_" .. amount] then
			message[name] = nil
			local removed = str_machine.cargo.remove(player, item, amount)
			str_transmissions.count_relic(name, item, "discarded", removed)
			refresh(player)
			return
		end
		if item and fields["drop_" .. amount] and drop_handler then
			local moved, problem = drop_handler(player, item, amount)
			local def = str_materials.get(item)
			message[name] = moved > 0 and ("Dropped %d %s into the crate."):format(moved, def and def.description or item)
				or problem
			refresh(player)
			return
		end
	end
	local event = core.explode_table_event(fields.items or "")
	if event.type == "CHG" or event.type == "DCL" then
		local row = str_inventory.cargo_rows(player)[event.row]
		selected_item[name] = row and row.def.name
		message[name] = nil
		refresh(player)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_tab[name], selected_item[name], armed[name] = nil, nil, nil
	message[name] = nil
	expanded_analysis[name] = nil
	signal_row[name], decode_input[name], decode_result[name] = nil, nil, nil
	for _, def in ipairs(TABS) do
		if def.on_leave then
			def.on_leave(name)
		end
	end
end)
