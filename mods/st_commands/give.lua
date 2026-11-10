-- Debug window: add or remove credits and items through the same APIs the game uses
local FORMNAME = "st_commands:give"
local WIDTH, HEIGHT = 13, 12
local MARGIN = 0.4
local TABLE_W = WIDTH - 2 * MARGIN
local CREDIT_STEPS = {-1000, -100, -10, 10, 100, 1000}
local ITEM_STEPS = {1, 10, 100}
local TARGETS = {
	{label = "Cargo Hold", store = st_machine.cargo},
	{label = "Shop Storage", store = st_storage},
}

local Y_CREDITS = st_gui.CONTENT_Y - 0.2
local Y_CREDIT_BUTTONS = Y_CREDITS + 0.6
local Y_TARGET = Y_CREDIT_BUTTONS + 1.0
local Y_TABLE = Y_TARGET + 0.9
local TABLE_H = 5.2
local Y_ADD = Y_TABLE + TABLE_H + 0.1
local Y_REMOVE = Y_ADD + 0.8
local Y_STATUS = Y_REMOVE + 1.1

local esc = core.formspec_escape

-- Per player: target index, selected item name, status text
local state = {}

local function get_state(name)
	state[name] = state[name] or {target = 1, status = ""}
	return state[name]
end

-- Every item with its count in the store (0 if none), so all of them are listed
local function all_items(store, player)
	local held = store.get(player)
	local contents = {}
	for _, def in ipairs(st_materials.list) do
		contents[def.name] = held[def.name] or 0
	end
	return contents
end

local function step_buttons(y, prefix, steps, label)
	local fs = {}
	local w = (TABLE_W - (#steps - 1) * 0.2) / #steps
	for i, step in ipairs(steps) do
		fs[#fs + 1] = ("button[%g,%g;%g,0.7;%s%d;%s]"):format(
			MARGIN + (i - 1) * (w + 0.2), y, w, prefix, step, esc(label(step)))
	end
	return table.concat(fs)
end

local function build(player)
	local st = get_state(player:get_player_name())
	local target = TARGETS[st.target]
	local table_fs = st_inventory.item_table(all_items(target.store, player), {
		x = MARGIN, y = Y_TABLE, w = TABLE_W, h = TABLE_H, name = "items", selected = st.item,
	})
	local labels = {}
	for i, t in ipairs(TARGETS) do
		labels[i] = esc(t.label)
	end
	return table.concat({
		st_gui.header(WIDTH, HEIGHT, "Give (debug)"),
		("label[%g,%g;%s]"):format(MARGIN, Y_CREDITS + 0.25,
			esc("Credits: " .. st_player_resources.format_credits(st_player_resources.get_credits(player)))),
		step_buttons(Y_CREDIT_BUTTONS, "credits_", CREDIT_STEPS, function(s) return ("%+d"):format(s) end),
		("label[%g,%g;Target]"):format(MARGIN, Y_TARGET + 0.35),
		("dropdown[%g,%g;4,0.7;target;%s;%d;true]"):format(MARGIN + 1.5, Y_TARGET, table.concat(labels, ","), st.target),
		table_fs,
		step_buttons(Y_ADD, "add_", ITEM_STEPS, function(s) return "Add " .. s end),
		step_buttons(Y_REMOVE, "remove_", ITEM_STEPS, function(s) return "Remove " .. s end),
		("label[%g,%g;%s]"):format(MARGIN, Y_STATUS, esc(st.status)),
	})
end

local function show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

local function change_credits(player, amount)
	if amount >= 0 then
		st_player_resources.add_credits(player, amount)
		return ("Added %d credits"):format(amount)
	end
	if st_player_resources.spend_credits(player, -amount) then
		return ("Removed %d credits"):format(-amount)
	end
	return "Not enough credits"
end

local function change_items(player, st, mode, count)
	local def = st.item and st_materials.get(st.item)
	if not def then
		return "Select an item first"
	end
	local store = TARGETS[st.target].store
	if mode == "add" then
		local added = store.add(player, def.name, count)
		return ("Added %d of %d %s%s"):format(added, count, def.description, added < count and " (full)" or "")
	end
	return ("Removed %d of %d %s"):format(store.remove(player, def.name, count), count, def.description)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit or not core.check_player_privs(player, {give = true}) then
		return
	end
	local st = get_state(player:get_player_name())
	local target = tonumber(fields.target)
	if target and TARGETS[target] then
		st.target = target
	end
	for key in pairs(fields) do
		local kind, amount = key:match("^(%a+)_(-?%d+)$")
		amount = tonumber(amount)
		if kind == "credits" then
			st.status = change_credits(player, amount)
		elseif kind == "add" or kind == "remove" then
			st.status = change_items(player, st, kind, amount)
		end
	end
	local event = core.explode_table_event(fields.items or "")
	if event.type == "CHG" or event.type == "DCL" then
		local row = st_inventory.rows(all_items(TARGETS[st.target].store, player))[event.row]
		st.item = row and row.def.name
	end
	show(player)
end)

core.register_on_leaveplayer(function(player)
	state[player:get_player_name()] = nil
end)

core.register_chatcommand("give", {
	description = "Debug window to add or remove credits and items",
	privs = {give = true},
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "No such player."
		end
		show(player)
		return true
	end,
})
