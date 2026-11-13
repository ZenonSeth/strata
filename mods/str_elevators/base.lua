local FORMNAME = "str_elevators:main"
local META_NODE, META_PARAM2 = "str_elevators:backing", "str_elevators:backing_param2"
local SLICE_Z = str_utils.constants.slice_z
local SURFACE_Y = str_utils.constants.surface_y
local MIN_DISTANCE = str_elevators.MIN_DISTANCE
local MIN_X_DISTANCE = str_elevators.MIN_X_DISTANCE
local NAME_MAX = 24

local esc = core.formspec_escape

local NODES = {
	surface_low = {kind = "surface", description = "Elevator Surface (lower)"},
	surface_high = {kind = "surface", description = "Elevator Surface (upper)"},
	stop = {kind = "stop", description = "Elevator Stop"},
}
local kind_of_node = {}
for id, def in pairs(NODES) do
	local name = "str_elevators:" .. id
	kind_of_node[name] = def.kind
	local node = {
		description = def.description,
		tiles = {"str_elevators_" .. id .. ".png"},
		groups = {not_in_creative_inventory = 1},
		diggable = false,
		is_ground_content = false,
		str_interact = "elevator",
	}
	if id == "surface_high" then
		node.drawtype = "nodebox"
		node.node_box = {type = "fixed", fixed = str_elevators.surface_high_boxes}
		node.paramtype = "light"
		node.sunlight_propagates = true
		node.tiles = {}
		for i, face in ipairs({"top", "bottom", "left", "right", "back", "front"}) do
			node.tiles[i] = "str_elevators_surface_high_" .. face .. ".png"
		end
	end
	core.register_node(name, node)
end

local ITEMS = {surface = "str_elevators:surface_station", stop = "str_elevators:stop_station"}

local rock, cover = {}, {}
for _, stratum in ipairs(str_nodes.data.strata) do
	rock["str_nodes:" .. stratum.name] = true
end
for _, biome in ipairs(str_utils.constants.biomes) do
	cover["str_nodes:surface_" .. biome.name] = true
	cover["str_nodes:surface_" .. biome.name .. "_back"] = true
end

local function is_rock(pos)
	return rock[core.get_node(pos).name] == true
end

-- Rock or the hill's surface cover
local function is_ground(pos)
	local name = core.get_node(pos).name
	return rock[name] == true or cover[name] == true
end

-- What a surface station may replace: ground, air, grass and bushes and trees; never buildings, pads or interactables
local function is_clearable(pos)
	local name = core.get_node(pos).name
	return rock[name] or cover[name] or name == "air" or name:find("^str_decor:") ~= nil
end

local function offset_y(pos, dy)
	return vector.offset(pos, 0, dy, 0)
end

-- Sets name at pos, remembering the ground it replaces (anything else restores as air)
local function put(pos, name)
	local old = core.get_node(pos)
	core.set_node(pos, {name = name})
	if rock[old.name] or cover[old.name] then
		local meta = core.get_meta(pos)
		meta:set_string(META_NODE, old.name)
		meta:set_int(META_PARAM2, old.param2)
	end
end

local function restore(pos)
	local meta = core.get_meta(pos)
	local backing = meta:get_string(META_NODE)
	if backing ~= "" then
		core.set_node(pos, {name = backing, param2 = meta:get_int(META_PARAM2)})
	else
		core.set_node(pos, {name = "air"})
	end
end

-- Cell behind the machine, or nil if the machine is not driving
local function target_pos(player)
	local pos = str_machine.get_pos(player)
	return pos and vector.round(vector.new(pos.x, pos.y, SLICE_Z + 1))
end

-- Window state per player: {kind, x, y (the stop, or the surface station's lower node), confirm, selected}
local open_at = {}

local function station_at(pos)
	local name = core.get_node(pos).name
	local kind = kind_of_node[name]
	if not kind then
		return nil
	end
	local y = name == "str_elevators:surface_high" and pos.y - 1 or pos.y
	return {kind = kind, x = pos.x, y = y}
end

-- The nodes that make up a station
local function station_nodes(st)
	local pos = vector.new(st.x, st.y, SLICE_Z + 1)
	if st.kind == "surface" then
		return {pos, offset_y(pos, 1)}
	end
	return {pos}
end

local function still_there(st)
	for _, pos in ipairs(station_nodes(st)) do
		if not kind_of_node[core.get_node(pos).name] then
			return false
		end
	end
	return true
end

-- Places other than the station itself, for the window's list
local function destinations(st, net)
	local list = {}
	for _, dest in ipairs(str_elevators.destinations(net)) do
		if dest.y ~= st.y then
			list[#list + 1] = dest
		end
	end
	return list
end

local function is_live(st, net)
	return net ~= nil and (st.kind == "surface" or str_elevators.stop_index(net, st.y) ~= nil)
end

local PAD = 0.7
local WIDTH = 10
local TABLE_H = 3.4
local FIELD_W, BUTTON_W, BUTTON_GAP = 5.6, 2.8, 0.2
local TABLE_COLUMNS = {
	{title = "Destination", spec = "text,width=14,padding=0.3"},
	{title = "Depth", spec = "text,width=6,padding=0.3"},
}
local ROW_H = 0.8
local HEIGHT = str_gui.CONTENT_Y + 0.1 + ROW_H + 0.3 + TABLE_H + 0.3 + 0.6 + 0.3 + ROW_H + 0.4

local function stop_name(net, y)
	local i = str_elevators.stop_index(net, y)
	return i and net.stops[i].name or ""
end

local function build(player_name)
	local st = open_at[player_name]
	local net = str_elevators.get_network(st.x)
	local title = st.kind == "surface" and "Elevator - Surface station" or "Elevator stop"
	local fs = {str_gui.header(WIDTH, HEIGHT, title)}
	local y = str_gui.CONTENT_Y + 0.1
	local live = is_live(st, net)
	local buttons_y = HEIGHT - ROW_H - 0.4
	local button_x = PAD
	if not live then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(PAD, y + 0.4, esc("This stop is not connected to a surface station."))
	else
		if st.kind == "stop" then
			fs[#fs + 1] = "field_close_on_enter[name;false]"
			fs[#fs + 1] = str_gui.input_bg(PAD, y, FIELD_W, ROW_H)
			fs[#fs + 1] = ("field[%g,%g;%g,%g;name;;%s]"):format(PAD, y, FIELD_W, ROW_H, esc(stop_name(net, st.y)))
			fs[#fs + 1] = ("button[%g,%g;%g,%g;rename;Rename]"):format(PAD + FIELD_W + BUTTON_GAP, y, BUTTON_W, ROW_H)
		else
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(PAD, y + ROW_H / 2,
				esc(("%d connected stop%s"):format(#net.stops, #net.stops == 1 and "" or "s")))
		end
		local rows, selected = {}, 0
		for i, dest in ipairs(destinations(st, net)) do
			rows[i] = {cells = {dest.name, ("%d m"):format(math.max(0, SURFACE_Y - dest.y))}}
			if dest.y == st.selected then
				selected = i
			end
		end
		fs[#fs + 1] = str_gui.list_table({
			x = PAD, y = y + ROW_H + 0.3, w = WIDTH - 2 * PAD, h = TABLE_H, name = "dests",
			columns = TABLE_COLUMNS, rows = rows, selected = selected,
		})
		if selected > 0 then
			fs[#fs + 1] = ("button[%g,%g;%g,%g;go;Go]"):format(button_x, buttons_y, BUTTON_W, ROW_H)
		end
		button_x = button_x + BUTTON_W + BUTTON_GAP
	end
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
	local st = station_at(pos)
	local name = player:get_player_name()
	if not st or str_elevators.is_traveling(name) then
		return
	end
	open_at[name] = st
	show(name)
end

str_interact.register("elevator", {label = "Elevator", on_use = open})

local function pick_up(player, st)
	local name = player:get_player_name()
	local net = str_elevators.get_network(st.x)
	if st.kind == "surface" and net and #net.stops > 0 and not st.confirm then
		st.confirm = true
		show(name, ("%d stop%s will be disconnected. Pick up again to confirm."):format(
			#net.stops, #net.stops == 1 and "" or "s"))
		return
	end
	local stack = ItemStack(ITEMS[st.kind])
	local inv = player:get_inventory()
	if not inv:room_for_item("main", stack) then
		show(name, "Your inventory is full.")
		return
	end
	for _, pos in ipairs(station_nodes(st)) do
		restore(pos)
	end
	if st.kind == "surface" then
		str_elevators.save_network(st.x, nil)
	elseif net then
		local i = str_elevators.stop_index(net, st.y)
		if i then
			table.remove(net.stops, i)
			str_elevators.save_network(st.x, net)
		end
	end
	inv:add_item("main", stack)
	open_at[name] = nil
	core.close_formspec(name, FORMNAME)
end

local function rename(st, text)
	local net = str_elevators.get_network(st.x)
	local i = net and str_elevators.stop_index(net, st.y)
	local clean = text:gsub("[^%w _'%-%.]", ""):sub(1, NAME_MAX):match("^%s*(.-)%s*$")
	if not i or clean == "" then
		return
	end
	net.stops[i].name = clean
	str_elevators.save_network(st.x, net)
end

local function go(player, st)
	local net = str_elevators.get_network(st.x)
	if not net or not is_live(st, net) or not st.selected then
		return
	end
	for _, dest in ipairs(destinations(st, net)) do
		if dest.y == st.selected then
			local name = player:get_player_name()
			open_at[name] = nil
			core.close_formspec(name, FORMNAME)
			str_elevators.travel(player, st.x, st.y, dest.y)
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
		local net = str_elevators.get_network(st.x)
		local event = core.explode_table_event(fields.dests)
		if net and (event.type == "CHG" or event.type == "DCL") then
			local dest = destinations(st, net)[event.row]
			st.selected = dest and dest.y
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

-- Placement: each returns a problem text, or nil once the station is placed

local function place_surface(_, pos)
	if pos.y < SURFACE_Y then
		return "A surface station must be at or above the surface."
	end
	if str_elevators.get_network(pos.x) then
		return "This column already has a surface station."
	end
	if str_elevators.network_within(pos.x, MIN_X_DISTANCE) then
		return ("Surface stations must be %d metres apart."):format(MIN_X_DISTANCE)
	end
	local upper = offset_y(pos, 1)
	if not (is_ground(offset_y(pos, -1)) and is_clearable(pos) and is_clearable(upper)) then
		return "A surface station can't be placed here."
	end
	put(pos, "str_elevators:surface_low")
	put(upper, "str_elevators:surface_high")
	str_elevators.save_network(pos.x, {top = pos.y, stops = {}, counter = 0})
end

local function place_stop(player, pos)
	if pos.y >= SURFACE_Y then
		return "A stop must be below the surface."
	end
	local net = str_elevators.get_network(pos.x)
	if not net then
		return "A stop needs a surface station in this column."
	end
	if not (is_rock(pos) and is_rock(offset_y(pos, -1))) then
		return "A stop can't be placed here."
	end
	local too_close = math.abs(pos.y - net.top) < MIN_DISTANCE
	for _, stop in ipairs(net.stops) do
		too_close = too_close or math.abs(pos.y - stop.y) < MIN_DISTANCE
	end
	if too_close then
		return ("Stops must be %d metres from the surface station and each other."):format(MIN_DISTANCE)
	end
	net.counter = (net.counter or 0) + 1
	net.stops[#net.stops + 1] = {y = pos.y, name = "Stop " .. net.counter}
	str_elevators.save_network(pos.x, net)
	put(pos, "str_elevators:stop")
	open(player, pos)
end

local function register_item(kind, description, image, place)
	core.register_craftitem(ITEMS[kind], {
		description = description,
		inventory_image = image,
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
end

register_item("surface", "Elevator Surface Station\nPlaced behind the machine at the surface; stops are placed below it",
	"str_elevators_surface_high.png", place_surface)
register_item("stop", "Elevator Stop\nPlaced behind the machine below a surface station in the same column",
	"str_elevators_stop.png", place_stop)
