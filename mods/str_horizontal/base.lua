local FORMNAME = "str_horizontal:main"
local NODE = "str_horizontal:waypoint"
local ITEM = "str_horizontal:waypoint"
local SLICE_Z = str_utils.constants.slice_z
local SURFACE_Y = str_utils.constants.surface_y
local MIN_DISTANCE = str_horizontal.MIN_DISTANCE
local NAME_MAX = 24

local esc = core.formspec_escape

core.register_node(NODE, {
	description = "Waypoint",
	tiles = {"str_horizontal_waypoint.png"},
	groups = {not_in_creative_inventory = 1},
	diggable = false,
	is_ground_content = false,
	str_interact = "waypoint",
})

local function node_pos(x, y)
	return vector.new(x, y, SLICE_Z + 1)
end

local function target_pos(player)
	local pos = str_machine.get_pos(player)
	return pos and vector.round(vector.new(pos.x, pos.y, SLICE_Z + 1))
end

-- Window state per player: {x, y, selected (x of the chosen destination), message}
local open_at = {}

local function still_there(st)
	return core.get_node(node_pos(st.x, st.y)).name == NODE and str_horizontal.get(st.x) ~= nil
end

-- Every waypoint, nearest first, so the current one (marked) leads the list
local function destinations(st)
	local list = str_horizontal.all()
	for _, wp in ipairs(list) do
		wp.distance = math.abs(wp.x - st.x)
		wp.current = wp.x == st.x
	end
	table.sort(list, function(a, b) return a.distance < b.distance end)
	return list
end

local PAD = 0.7
local WIDTH = 10
local TABLE_H = 3.4
local FIELD_W, BUTTON_W, BUTTON_GAP = 5.6, 2.8, 0.2
local TABLE_COLUMNS = {
	{title = "Destination", spec = "text,width=14,padding=0.3"},
	{title = "Distance", spec = "text,width=8,padding=0.3"},
}
local ROW_H = 0.8
local HEIGHT = str_gui.CONTENT_Y + 0.1 + ROW_H + 0.3 + TABLE_H + 0.3 + 0.6 + 0.3 + ROW_H + 0.4

local function build(player_name)
	local st = open_at[player_name]
	local wp = str_horizontal.get(st.x)
	local fs = {str_gui.header(WIDTH, HEIGHT, "Waypoint")}
	local y = str_gui.CONTENT_Y + 0.1
	local buttons_y = HEIGHT - ROW_H - 0.4
	fs[#fs + 1] = "field_close_on_enter[name;false]"
	fs[#fs + 1] = str_gui.input_bg(PAD, y, FIELD_W, ROW_H)
	fs[#fs + 1] = ("field[%g,%g;%g,%g;name;;%s]"):format(PAD, y, FIELD_W, ROW_H, esc(wp.name))
	fs[#fs + 1] = ("button[%g,%g;%g,%g;rename;Rename]"):format(PAD + FIELD_W + BUTTON_GAP, y, BUTTON_W, ROW_H)
	local rows, selected, can_go = {}, 0, false
	for i, dest in ipairs(destinations(st)) do
		rows[i] = {cells = dest.current and {dest.name .. " (Current)", ""}
			or {dest.name, ("%d m %s"):format(dest.distance, dest.x < st.x and "west" or "east")}}
		if dest.x == st.selected then
			selected, can_go = i, not dest.current
		end
	end
	fs[#fs + 1] = str_gui.list_table({
		x = PAD, y = y + ROW_H + 0.3, w = WIDTH - 2 * PAD, h = TABLE_H, name = "dests",
		columns = TABLE_COLUMNS, rows = rows, selected = selected,
	})
	local button_x = PAD
	if can_go then
		fs[#fs + 1] = ("button[%g,%g;%g,%g;go;Go]"):format(button_x, buttons_y, BUTTON_W, ROW_H)
	end
	button_x = button_x + BUTTON_W + BUTTON_GAP
	fs[#fs + 1] = ("button[%g,%g;%g,%g;pickup;Pick up]"):format(button_x, buttons_y, BUTTON_W, ROW_H)
	fs[#fs + 1] = ("button_exit[%g,%g;%g,%g;done;Done]"):format(
		button_x + BUTTON_W + BUTTON_GAP, buttons_y, BUTTON_W, ROW_H)
	if st.message then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(PAD, buttons_y - 0.4, esc(st.message))
	end
	return table.concat(fs)
end

local function show(player_name, message)
	open_at[player_name].message = message
	core.show_formspec(player_name, FORMNAME, build(player_name))
end

local function open(player, pos)
	local name = player:get_player_name()
	if core.get_node(pos).name ~= NODE or str_elevators.is_traveling(name) or not str_horizontal.get(pos.x) then
		return
	end
	open_at[name] = {x = pos.x, y = pos.y}
	show(name)
end

str_interact.register("waypoint", {label = "Waypoint", on_use = open})

local function pick_up(player, st)
	local name = player:get_player_name()
	local stack = ItemStack(ITEM)
	local inv = player:get_inventory()
	if not inv:room_for_item("main", stack) then
		show(name, "Your inventory is full.")
		return
	end
	str_elevators.restore(node_pos(st.x, st.y))
	str_horizontal.save(st.x, nil)
	inv:add_item("main", stack)
	open_at[name] = nil
	core.close_formspec(name, FORMNAME)
end

local function rename(st, text)
	local wp = str_horizontal.get(st.x)
	local clean = text:gsub("[^%w _'%-%.]", ""):sub(1, NAME_MAX):match("^%s*(.-)%s*$")
	if not wp or clean == "" then
		return
	end
	wp.name = clean
	str_horizontal.save(st.x, wp)
end

local function go(player, st)
	if not st.selected then
		return
	end
	for _, dest in ipairs(destinations(st)) do
		if dest.x == st.selected and not dest.current then
			local name = player:get_player_name()
			open_at[name] = nil
			core.close_formspec(name, FORMNAME)
			str_elevators.travel_to(player, vector.new(dest.x, dest.y, SLICE_Z), dest.distance)
			return
		end
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	if fields.quit then
		open_at[name] = nil
		return
	end
	local st = open_at[name]
	if not st or str_elevators.is_traveling(name) or not still_there(st) then
		open_at[name] = nil
		core.close_formspec(name, FORMNAME)
		return
	end
	if fields.pickup then
		pick_up(player, st)
	elseif fields.rename or fields.key_enter_field == "name" then
		rename(st, fields.name or "")
		show(name)
	elseif fields.go then
		go(player, st)
	elseif fields.dests then
		local event = core.explode_table_event(fields.dests)
		if event.type == "CHG" or event.type == "DCL" then
			local dest = destinations(st)[event.row]
			st.selected = dest and dest.x
			if event.type == "DCL" and dest then
				go(player, st)
			else
				show(name)
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	open_at[player:get_player_name()] = nil
end)

-- Returns a problem text, or nil once the waypoint is placed
local function place(player, pos)
	if pos.y < SURFACE_Y then
		return "A waypoint must be at or above the surface."
	end
	if str_horizontal.within(pos.x, MIN_DISTANCE) then
		return ("Waypoints must be %d metres apart."):format(MIN_DISTANCE)
	end
	if not (str_elevators.is_ground(vector.offset(pos, 0, -1, 0)) and str_elevators.is_clearable(pos)) then
		return "A waypoint can't be placed here."
	end
	str_elevators.put(pos, NODE)
	str_horizontal.save(pos.x, {y = pos.y, name = "Waypoint " .. str_horizontal.next_number()})
	open(player, pos)
end

core.register_craftitem(ITEM, {
	description = "Waypoint\nPlaced behind the machine at the surface; travel between all waypoints",
	inventory_image = "str_horizontal_waypoint.png",
	on_use = function(itemstack, user)
		if not user or str_mode.get(user) ~= "vehicle" or str_machine.is_dead(user)
				or str_elevators.is_traveling(user:get_player_name()) then
			return
		end
		local pos = target_pos(user)
		if not pos then
			return
		end
		local problem = place(user, pos)
		if problem then
			str_utils.show_popup(user:get_player_name(), problem, 2, true)
			return
		end
		itemstack:take_item()
		return itemstack
	end,
	on_drop = function(itemstack) return itemstack end,
})
