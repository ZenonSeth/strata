-- Debug window: add or remove credits, items and owned machine parts through the same APIs the game uses
local FORMNAME = "st_commands:give"
local WIDTH, HEIGHT = 13, 12.8
local MARGIN = 0.4
local TABLE_W = WIDTH - 2 * MARGIN
local CREDIT_STEPS = {-1000, -100, -10, 10, 100, 1000}
local ITEM_STEPS = {1, 10, 100}
local TARGETS = {
	{label = "Cargo Hold", store = st_machine.cargo},
	{label = "Shop Storage", store = st_storage},
}
local TABS = {
	{id = "items", label = "Items"},
	{id = "upgrades", label = "Upgrades"},
}

local Y_TABS = st_gui.CONTENT_Y - 0.2
local Y_CREDITS = Y_TABS + 0.8
local Y_CREDIT_BUTTONS = Y_CREDITS + 0.6
local Y_TARGET = Y_CREDIT_BUTTONS + 1.0
local Y_TABLE = Y_TARGET + 0.9
local TABLE_H = 5.2
local Y_ADD = Y_TABLE + TABLE_H + 0.1
local Y_REMOVE = Y_ADD + 0.8
local Y_STATUS = Y_REMOVE + 1.1

local Y_PARTS = Y_TABS + 0.9
local PARTS_H = 7.2
local Y_PART_BUTTONS = Y_PARTS + PARTS_H + 0.1
local Y_PART_STATUS = Y_PART_BUTTONS + 0.9

local esc = core.formspec_escape
local stats = st_machine.stats

-- Per player: tab id, target index, selected item name, selected part row, status text
local state = {}

local function get_state(name)
	state[name] = state[name] or {tab = "items", target = 1, status = ""}
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

-- Every part level of every category, in order: table rows and the {id, name} each row stands for
local function part_rows(player)
	local rows, parts = {}, {}
	for _, category in ipairs(st_machine_data.upgrades) do
		local equipped = stats.get_level(player, category.id).name
		for _, level in ipairs(category.levels) do
			local mark = ""
			if level.name == equipped then
				mark = "Equipped"
			elseif stats.has_level(player, category.id, level.name) then
				mark = "Owned"
			end
			rows[#rows + 1] = {cells = {category.title, level.description, mark}}
			parts[#parts + 1] = {id = category.id, name = level.name}
		end
	end
	return rows, parts
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

local function tab_buttons(st)
	local fs = {}
	for i, tab in ipairs(TABS) do
		local x = MARGIN + (i - 1) * 2.7
		fs[#fs + 1] = ("button[%g,%g;2.5,0.7;tab_%s;%s]"):format(x, Y_TABS, tab.id, esc(tab.label))
		if tab.id == st.tab then
			fs[#fs + 1] = ("box[%g,%g;2.5,0.06;#e0a020]"):format(x, Y_TABS + 0.72)
		end
	end
	return table.concat(fs)
end

local function build_items(player, st)
	local target = TARGETS[st.target]
	local table_fs = st_inventory.item_table(all_items(target.store, player), {
		x = MARGIN, y = Y_TABLE, w = TABLE_W, h = TABLE_H, name = "items", selected = st.item,
	})
	local labels = {}
	for i, t in ipairs(TARGETS) do
		labels[i] = esc(t.label)
	end
	return table.concat({
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

local function build_upgrades(player, st)
	local rows = part_rows(player)
	local half = (TABLE_W - 0.2) / 2
	return table.concat({
		st_gui.list_table({
			x = MARGIN, y = Y_PARTS, w = TABLE_W, h = PARTS_H, name = "parts", selected = st.part_row,
			columns = {
				{title = "Part", spec = "text,width=10,padding=0.3"},
				{title = "Level", spec = "text,width=24,padding=0.3"},
				{title = "State", spec = "text,width=10,padding=0.3"},
			},
			rows = rows,
		}),
		("button[%g,%g;%g,0.7;part_build;Build (own)]"):format(MARGIN, Y_PART_BUTTONS, half),
		("button[%g,%g;%g,0.7;part_remove;Remove]"):format(MARGIN + half + 0.2, Y_PART_BUTTONS, half),
		("label[%g,%g;%s]"):format(MARGIN, Y_PART_STATUS, esc(st.status)),
	})
end

local function build(player)
	local st = get_state(player:get_player_name())
	return table.concat({
		st_gui.header(WIDTH, HEIGHT, "Give (debug)"),
		tab_buttons(st),
		st.tab == "upgrades" and build_upgrades(player, st) or build_items(player, st),
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

local function change_part(player, st, mode)
	local _, parts = part_rows(player)
	local part = st.part_row and parts[st.part_row]
	if not part then
		return "Select a part first"
	end
	local label = st_machine_data.get_upgrade(part.id).title .. " " .. part.name
	if mode == "build" then
		if stats.has_level(player, part.id, part.name) then
			return label .. " is already owned"
		end
		return stats.build_level(player, part.id, part.name) and (label .. " built") or "Cannot build that"
	end
	local ok, reason = stats.remove_level(player, part.id, part.name)
	return ok and (label .. " removed") or reason
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit or not core.check_player_privs(player, {give = true}) then
		return
	end
	local st = get_state(player:get_player_name())
	for _, tab in ipairs(TABS) do
		if fields["tab_" .. tab.id] and st.tab ~= tab.id then
			st.tab = tab.id
			st.status = ""
		end
	end
	if st.tab == "upgrades" then
		local event = core.explode_table_event(fields.parts or "")
		if event.type == "CHG" or event.type == "DCL" then
			st.part_row = event.row
		end
		if fields.part_build then
			st.status = change_part(player, st, "build")
		elseif fields.part_remove then
			st.status = change_part(player, st, "remove")
		end
		show(player)
		return
	end
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
	description = "Debug window to add or remove credits, items and owned parts",
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
