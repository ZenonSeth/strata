local unit = str_utils.constants.volume_unit
local FORMNAME = "str_crate:main"
local WIDTH = 13
local MARGIN = 0.4
local LABEL_H = 0.5
local BASE_TABLE_H = 2.8
local BASE_HEIGHT = str_gui.CONTENT_Y - 0.2 + LABEL_H + 2 * BASE_TABLE_H + 3 * 0.1 + 2 * 0.7 + LABEL_H + 0.9
local TABLE_H = BASE_TABLE_H + BASE_HEIGHT * 0.25
local BUTTON_H = 0.7
local GAP = 0.1

local Y_HOLD_LABEL = str_gui.CONTENT_Y - 0.2
local Y_HOLD = Y_HOLD_LABEL + LABEL_H
local Y_DEPOSIT = Y_HOLD + TABLE_H + GAP
local Y_WITHDRAW = Y_DEPOSIT + BUTTON_H + GAP
local Y_STORAGE_LABEL = Y_WITHDRAW + BUTTON_H + 0.1
local Y_STORAGE = Y_STORAGE_LABEL + LABEL_H
local HEIGHT = Y_STORAGE + TABLE_H + 0.9
local TABLE_W = WIDTH - 2 * MARGIN
local BUTTON_W, BUTTON_GAP = 3.2, 0.2

local esc = core.formspec_escape
local num = str_inventory.num
local cargo = str_machine.cargo
local storage = str_storage

-- Selected item name per table, per player
local selected_hold = {}
local selected_stock = {}

local function button_row(y, buttons)
	local fs = {}
	for i, button in ipairs(buttons) do
		if button.show then
			fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(
				MARGIN + (i - 1) * (BUTTON_W + BUTTON_GAP), y, BUTTON_W, BUTTON_H, button.id, button.text)
		end
	end
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local held, stored = cargo.get(player), storage.get(player)
	local hold_fs, _, hold_sel = str_inventory.item_table(held, {
		x = MARGIN, y = Y_HOLD, w = TABLE_W, h = TABLE_H, name = "hold", selected = selected_hold[name],
	})
	local stock_fs, _, stock_sel = str_inventory.item_table(stored, {
		x = MARGIN, y = Y_STORAGE, w = TABLE_W, h = TABLE_H, name = "stock", selected = selected_stock[name],
		empty = "The storage is empty.",
	})
	local capacity = str_utils.constants.storage_capacity
	return table.concat({
		str_gui.header(WIDTH, HEIGHT, "Storage"),
		("label[%g,%g;%s]"):format(MARGIN, Y_HOLD_LABEL + LABEL_H / 2, "Cargo Hold"),
		hold_fs,
		button_row(Y_DEPOSIT, {
			{id = "deposit_one", text = "Deposit 1", show = hold_sel > 0},
			{id = "deposit_stack", text = "Deposit Stack", show = hold_sel > 0},
			{id = "deposit_all", text = "Deposit All", show = next(held) ~= nil},
		}),
		button_row(Y_WITHDRAW, {
			{id = "withdraw_one", text = "Withdraw 1", show = stock_sel > 0},
			{id = "withdraw_stack", text = "Withdraw Stack", show = stock_sel > 0},
			{id = "withdraw_all", text = "Withdraw All", show = next(stored) ~= nil},
		}),
		("label[%g,%g;%s]"):format(MARGIN, Y_STORAGE_LABEL + LABEL_H / 2, "Storage"),
		stock_fs,
		("label[%g,%g;%s]"):format(MARGIN, HEIGHT - 0.45, esc(("Hold: %s / %s %s     Storage: %s / %s %s"):format(
			num(cargo.volume(player)), num(str_machine.stats.get(player).cargo_capacity), unit,
			num(storage.volume(player)), num(capacity), unit))),
	})
end

function str_crate.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local name = player:get_player_name()
	local hold_item, stock_item = selected_hold[name], selected_stock[name]
	if fields.deposit_one and hold_item then
		storage.deposit(player, hold_item, 1)
	elseif fields.deposit_stack and hold_item then
		storage.deposit(player, hold_item, cargo.get(player)[hold_item] or 0)
	elseif fields.deposit_all then
		storage.deposit_all(player)
	elseif fields.withdraw_one and stock_item then
		storage.withdraw(player, stock_item, 1)
	elseif fields.withdraw_stack and stock_item then
		storage.withdraw(player, stock_item, storage.get(player)[stock_item] or 0)
	elseif fields.withdraw_all then
		storage.withdraw_all(player)
	else
		local event = core.explode_table_event(fields.hold or "")
		if event.type == "CHG" or event.type == "DCL" then
			local row = str_inventory.cargo_rows(player)[event.row]
			selected_hold[name], selected_stock[name] = row and row.def.name, nil
		else
			event = core.explode_table_event(fields.stock or "")
			if event.type ~= "CHG" and event.type ~= "DCL" then
				return
			end
			local row = str_inventory.rows(storage.get(player))[event.row]
			selected_stock[name], selected_hold[name] = row and row.def.name, nil
		end
	end
	str_crate.show(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_hold[name], selected_stock[name] = nil, nil
end)

str_interior.register_on_use(str_utils.constants.interact.warehouse, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		selected_hold[player_name], selected_stock[player_name] = nil, nil
		str_crate.show(player)
	end
end)
