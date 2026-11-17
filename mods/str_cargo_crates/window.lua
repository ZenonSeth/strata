local crates = str_cargo_crates

local unit = str_utils.constants.volume_unit
local capacity = str_utils.constants.cargo_crate.capacity
local FORMNAME = "str_cargo_crates:main"
local WIDTH = 13
local MARGIN = 0.4
local LABEL_H = 0.5
local TABLE_H = 3.6
local BUTTON_H = 0.7
local GAP = 0.1
local FOOTER_H = 0.7

local Y_CRATE_LABEL = str_gui.CONTENT_Y - 0.2
local Y_CRATE = Y_CRATE_LABEL + LABEL_H
local Y_WITHDRAW = Y_CRATE + TABLE_H + GAP
local Y_DEPOSIT = Y_WITHDRAW + BUTTON_H + GAP
local Y_HOLD_LABEL = Y_DEPOSIT + BUTTON_H + 0.1
local Y_HOLD = Y_HOLD_LABEL + LABEL_H
local Y_FOOTER = Y_HOLD + TABLE_H + 0.2
local HEIGHT = Y_FOOTER + FOOTER_H + 0.3
local TABLE_W = WIDTH - 2 * MARGIN
local BUTTON_W, BUTTON_GAP = 3, 0.15
local TOGGLE_W = 1.4
local DESTROY_W, DESTROY_H = 2.2, 0.7
local PRIVATE_TIP = "On: only you can place or take from this crate\nOff: anyone can place or take from this crate"

local esc = core.formspec_escape
local num = str_inventory.num
local cargo = str_machine.cargo

-- player name -> {pos, hold = selected item, crate = selected item}
local viewers = {}

local function button_row(y, buttons)
	local fs = {}
	for i, button in ipairs(buttons) do
		if button.show then
			local from_right = #buttons - i + 1
			fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(
				WIDTH - MARGIN - from_right * BUTTON_W - (from_right - 1) * BUTTON_GAP, y, BUTTON_W, BUTTON_H,
				button.id, button.text)
		end
	end
	return table.concat(fs)
end

local function footer(name, pos)
	local owner = crates.owner(pos)
	local fs = {"style_type[label;valign=center]"}
	if owner == name then
		local x = WIDTH - MARGIN - TOGGLE_W
		fs[#fs + 1] = ("label[%g,%g;%g,%g;Private]"):format(x - 1.4, Y_FOOTER, 1.3, FOOTER_H)
		fs[#fs + 1] = ("button[%g,%g;%g,%g;private;%s]"):format(x, Y_FOOTER, TOGGLE_W, FOOTER_H,
			crates.is_private(pos) and "On" or "Off")
		fs[#fs + 1] = ("tooltip[private;%s]"):format(esc(PRIVATE_TIP))
	else
		fs[#fs + 1] = "style_type[label;halign=right]"
		fs[#fs + 1] = ("label[%g,%g;%g,%g;%s]"):format(WIDTH / 2, Y_FOOTER, WIDTH / 2 - MARGIN, FOOTER_H,
			esc(core.colorize(str_gui.theme.muted, "Owner: ") .. (owner or "")))
		fs[#fs + 1] = "style_type[label;halign=left]"
	end
	fs[#fs + 1] = "style_type[label;valign=top]"
	return table.concat(fs)
end

local function build(player, view)
	local name = player:get_player_name()
	local held, stored = cargo.get(player), crates.get(view.pos)
	local hold_fs, _, hold_sel = str_inventory.item_table(held, {
		x = MARGIN, y = Y_HOLD, w = TABLE_W, h = TABLE_H, name = "hold", selected = view.hold,
	})
	local crate_fs, _, crate_sel = str_inventory.item_table(stored, {
		x = MARGIN, y = Y_CRATE, w = TABLE_W, h = TABLE_H, name = "crate", selected = view.crate,
		bg = "#241e19",
	})
	return table.concat({
		str_gui.header(WIDTH, HEIGHT, "Cargo Crate"),
		("label[%g,%g;%s]"):format(MARGIN, Y_HOLD_LABEL + LABEL_H / 2, "Cargo Hold"),
		crates.owner(view.pos) == name and table.concat({
			"style[destroy:hovered;bgcolor=#d04030]",
			("button[%g,%g;%g,%g;destroy;Destroy]"):format(WIDTH - MARGIN - DESTROY_W, Y_CRATE - 0.65,
				DESTROY_W, DESTROY_H),
			"tooltip[destroy;Destroys the crate and everything in it]",
		}) or "",
		hold_fs,
		button_row(Y_DEPOSIT, {
			{id = "deposit_one", text = "Deposit 1", show = hold_sel > 0},
			{id = "deposit_stack", text = "Deposit Stack", show = hold_sel > 0},
			{id = "deposit_all", text = "Deposit All", show = next(held) ~= nil},
		}),
		button_row(Y_WITHDRAW, {
			{id = "withdraw_one", text = "Withdraw 1", show = crate_sel > 0},
			{id = "withdraw_stack", text = "Withdraw Stack", show = crate_sel > 0},
			{id = "withdraw_all", text = "Withdraw All", show = next(stored) ~= nil},
		}),
		("label[%g,%g;%s]"):format(MARGIN, Y_CRATE_LABEL + LABEL_H / 2, "Crate"),
		crate_fs,
		("label[%g,%g;%s]"):format(MARGIN, Y_WITHDRAW + BUTTON_H / 2, esc(("Crate: %s / %s %s"):format(
			num(crates.volume(view.pos)), num(capacity), unit))),
		("label[%g,%g;%s]"):format(MARGIN, Y_FOOTER + FOOTER_H / 2, esc(("Hold: %s / %s %s"):format(
			num(cargo.volume(player)), num(str_machine.stats.get(player).cargo_capacity), unit))),
		footer(name, view.pos),
	})
end

-- The viewer's crate if they may still use it from where the machine is; closes the window otherwise
local function current(player)
	local name = player:get_player_name()
	local view = viewers[name]
	local machine_pos = str_mode.get(player) == "vehicle" and str_machine.get_pos(player)
	if view and machine_pos and vector.equals(vector.round(machine_pos), view.pos) and crates.can_use(name, view.pos) then
		return view
	end
	viewers[name] = nil
	core.close_formspec(name, FORMNAME)
end

local function show(player)
	local view = current(player)
	if view then
		core.show_formspec(player:get_player_name(), FORMNAME, build(player, view))
	end
end

-- Moves as many units as fit from the hold into the crate; returns how many moved
local function deposit(player, pos, name, count)
	local added = crates.add(pos, name, math.min(count, cargo.get(player)[name] or 0))
	if added > 0 then
		cargo.remove(player, name, added)
	end
	return added
end

-- Moves as many units as fit from the crate into the hold; returns how many moved
local function withdraw(player, pos, name, count)
	local added = cargo.add(player, name, math.min(count, crates.get(pos)[name] or 0))
	if added > 0 then
		crates.remove(pos, name, added)
	end
	return added
end

local function open(player, pos)
	local name = player:get_player_name()
	pos = vector.round(pos)
	if not crates.owner(pos) then
		return
	end
	if not crates.can_use(name, pos) then
		core.chat_send_player(name, "This crate is private.")
		return
	end
	viewers[name] = {pos = pos}
	show(player)
end

str_interact.register("cargo_crate", {label = "Cargo crate", on_use = open})

-- Everyone looking at a crate sees its changes; a crate that vanished or went private closes for them
crates.register_on_change(function(pos)
	for name, view in pairs(viewers) do
		local player = vector.equals(view.pos, pos) and core.get_player_by_name(name)
		if player then
			show(player)
		end
	end
end)

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	if fields.quit then
		viewers[name] = nil
		return
	end
	local view = current(player)
	if not view then
		return
	end
	local pos = view.pos
	if fields.destroy and crates.owner(pos) == name then
		for item, count in pairs(crates.destroy(pos)) do
			str_transmissions.count_relic(name, item, "discarded", count)
		end
		return
	elseif fields.private and crates.owner(pos) == name then
		crates.set_private(pos, not crates.is_private(pos))
	elseif fields.deposit_one and view.hold then
		deposit(player, pos, view.hold, 1)
	elseif fields.deposit_stack and view.hold then
		deposit(player, pos, view.hold, cargo.get(player)[view.hold] or 0)
	elseif fields.deposit_all then
		for item, count in pairs(cargo.get(player)) do
			deposit(player, pos, item, count)
		end
	elseif fields.withdraw_one and view.crate then
		withdraw(player, pos, view.crate, 1)
	elseif fields.withdraw_stack and view.crate then
		withdraw(player, pos, view.crate, crates.get(pos)[view.crate] or 0)
	elseif fields.withdraw_all then
		for item, count in pairs(crates.get(pos)) do
			withdraw(player, pos, item, count)
		end
	else
		local event = core.explode_table_event(fields.hold or "")
		if event.type == "CHG" or event.type == "DCL" then
			local row = str_inventory.cargo_rows(player)[event.row]
			view.hold, view.crate = row and row.def.name, nil
		else
			event = core.explode_table_event(fields.crate or "")
			if event.type ~= "CHG" and event.type ~= "DCL" then
				return
			end
			local row = str_inventory.rows(crates.get(pos))[event.row]
			view.crate, view.hold = row and row.def.name, nil
		end
	end
	show(player)
end)

core.register_on_leaveplayer(function(player)
	viewers[player:get_player_name()] = nil
end)
