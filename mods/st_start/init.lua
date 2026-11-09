-- First-ever spawn: each player gets their own copy of the shop/home interior in a grid in front of the
-- world, and starts on foot in the bed

st_start = {}

local storage = core.get_mod_storage()
local grid = st_utils.constants.interior
local SCHEMATIC = core.get_modpath("st_start") .. "/schems/shop_home.mts"
local SLOT_KEY = "st_start:slot"
local DONE_KEY = "st_start:started"
local BED_FOOT = "st_interior:home_bed_foot"
local DIGGER = "st_interior:digger_display"
local SPAWN_MARKER = "st_interior:shop_floor_spawn"
-- Seconds before the display digger's model appears on first spawn
local DIGGER_SPAWN_DELAY = 1
-- Feet this far above the bed foot node's centre (its top face), so the drop onto the blanket is small
local FEET_ABOVE_BED = 0.5

local function slot_origin(slot)
	return vector.new(
		grid.origin.x + (slot % grid.columns) * grid.spacing,
		grid.origin.y,
		grid.origin.z - math.floor(slot / grid.columns) * grid.spacing)
end

-- Lowest corner of the player's interior, nil before their first spawn
function st_start.get_origin(player)
	local slot = tonumber(player:get_meta():get_string(SLOT_KEY))
	return slot and slot_origin(slot)
end

local function allocate_slot(player)
	local slot = storage:get_int("next_slot")
	storage:set_int("next_slot", slot + 1)
	player:get_meta():set_string(SLOT_KEY, tostring(slot))
	return slot_origin(slot)
end

local function blocked(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return not def or def.walkable
end

-- Put the player on top of the node at node_pos (feet up_by above its centre), looking along its front,
-- or the opposite way with `behind`
local function stand_on(player, node_pos, up_by, behind)
	player:set_pos(vector.offset(node_pos, 0, up_by, 0))
	local yaw = core.dir_to_yaw(st_interior.facedir_front[core.get_node(node_pos).param2 % 4])
	player:set_look_horizontal(behind and yaw + math.pi or yaw)
	player:set_look_vertical(0)
end

local function place_player(player, origin, last)
	local foot = core.find_nodes_in_area(origin, last, BED_FOOT)[1]
	if foot then
		if blocked(vector.offset(foot, 0, 1, 0)) or blocked(vector.offset(foot, 0, 2, 0)) then
			core.log("warning", "st_start: no headroom above the bed foot at " .. core.pos_to_string(foot))
		end
		stand_on(player, foot, FEET_ABOVE_BED)
		return
	end
	core.log("error", "st_start: no " .. BED_FOOT .. " in the interior, using the shop spawn marker")
	local marker = core.find_nodes_in_area(origin, last, SPAWN_MARKER)[1]
	if marker then
		stand_on(player, marker, FEET_ABOVE_BED, true)
	else
		player:set_pos(vector.offset(origin, 1, 1, 1))
		player:set_look_vertical(0)
	end
end

-- Size of the interior schematic, read once; nil if it cannot be read
local interior_size
local function get_interior_size()
	if not interior_size then
		local schematic = core.read_schematic(SCHEMATIC, {write_yslice_prob = "none"})
		interior_size = schematic and schematic.size
	end
	return interior_size
end

-- Loads the interior's blocks, then calls on_done(player), with nil if the player left meanwhile
local function emerge_interior(name, origin, last, on_done)
	core.emerge_area(origin, last, function(_, action, calls_remaining)
		if action == core.EMERGE_ERRORED then
			core.log("error", "st_start: emerging the interior of " .. name .. " failed")
		end
		if calls_remaining > 0 then
			return
		end
		on_done(core.get_player_by_name(name))
	end)
end

-- The display entities are not saved; delay (seconds) is optional
local function ensure_diggers(origin, last, delay)
	for _, pos in ipairs(core.find_nodes_in_area(origin, last, DIGGER)) do
		st_interior.ensure_digger_entity(pos, 5, delay)
	end
end

local function first_spawn(player)
	local name = player:get_player_name()
	local size = get_interior_size()
	if not size then
		core.log("error", "st_start: cannot read " .. SCHEMATIC .. ", spawning normally")
		return
	end
	local origin = st_start.get_origin(player) or allocate_slot(player)
	local last = vector.offset(vector.add(origin, size), -1, -1, -1)
	-- On foot right away so the vehicle mode does not start a machine; the unloaded map holds the player
	st_mode.set(player, "foot")
	player:set_pos(origin)
	emerge_interior(name, origin, last, function(joined)
		if not joined then
			return -- still not started: the next join tries again, in the same slot
		end
		core.place_schematic(origin, SCHEMATIC, "0", nil, true)
		ensure_diggers(origin, last, DIGGER_SPAWN_DELAY)
		place_player(joined, origin, last)
		joined:get_meta():set_string(DONE_KEY, "1")
	end)
end

-- player name -> true while their interior is loading for an entry
local entering = {}

-- From driving: load the player's interior, then put them on foot at the shop spawn marker
function st_start.enter_workshop(player)
	local name = player:get_player_name()
	if entering[name] or st_mode.get(player) ~= "vehicle" then
		return
	end
	local origin, size = st_start.get_origin(player), get_interior_size()
	if not (origin and size) then
		core.log("error", "st_start: no interior to enter for " .. name)
		core.chat_send_player(name, "Your workshop is not ready yet.")
		return
	end
	local last = vector.offset(vector.add(origin, size), -1, -1, -1)
	entering[name] = true
	emerge_interior(name, origin, last, function(joined)
		entering[name] = nil
		if not joined or st_mode.get(joined) ~= "vehicle" then
			return
		end
		local marker = core.find_nodes_in_area(origin, last, SPAWN_MARKER)[1]
		if not marker then
			core.log("error", "st_start: no " .. SPAWN_MARKER .. " in the interior of " .. name)
			core.chat_send_player(name, "Your workshop has no entrance.")
			return
		end
		ensure_diggers(origin, last)
		st_mode.set(joined, "foot")
		stand_on(joined, marker, FEET_ABOVE_BED, true)
	end)
end

local MENU_FORM = "st_start:workshop"

function st_start.show_workshop_menu(player)
	local fs = st_gui.header(6, 3, "Mechanic shop")
		.. ("button_exit[1,%g;4,0.9;enter;Enter Workshop]"):format(st_gui.CONTENT_Y)
	core.show_formspec(player:get_player_name(), MENU_FORM, fs)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == MENU_FORM and fields.enter then
		st_start.enter_workshop(player)
	end
end)

core.register_on_leaveplayer(function(player)
	entering[player:get_player_name()] = nil
end)

-- Right-clicking the display digger boards the machine, which is respawned at its saved position if gone
st_interior.register_on_use(st_utils.constants.interact.drive, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player and st_mode.get(player) == "foot" then
		st_mode.set(player, "vehicle")
	end
end)

-- Runs after st_mode's join handler, which puts every player in the default mode
core.register_on_joinplayer(function(player)
	if player:get_meta():get_string(DONE_KEY) == "" then
		first_spawn(player)
	end
end)
