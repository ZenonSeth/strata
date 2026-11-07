st_machine = {}
st_machine.stats = dofile(core.get_modpath("st_machine") .. "/stats.lua")
st_machine.cargo = dofile(core.get_modpath("st_machine") .. "/cargo.lua")
local stats = st_machine.stats
local cargo = st_machine.cargo

local CAM_DISTANCE = 12
local CAM_START_DISTANCE = 4
-- The camera starts CAM_START_DISTANCE away and backs off to CAM_DISTANCE at this speed (nodes/s)
local CAM_PULLBACK_SPEED = 4
local VIEW_DISTANCE = 50
-- Fraction of the view distance where fog starts
local FOG_START = 0.4
local FOLLOW_SPEED = 8
-- How fast the machine reaches its target speed (nodes/s^2)
local ACCEL = 50
-- Climb speed is thrust / (1 + cargo weight * CARGO_DRAG)
local CARGO_DRAG = 0.05
local MAX_FALL_SPEED = 30
-- Easing onto the dig row/column
local ALIGN_SPEED = 3
local ALIGN_RATE = 10
local ALIGN_TOLERANCE = 0.03
-- Nodes per second squared; per session so it can differ per planet later
local DEFAULT_GRAVITY = 20
-- Seconds to dig a node unless it defines st_hardness
local DEFAULT_HARDNESS = 1
-- How far (in nodes) the machine bites into the node by the time the dig finishes
local PUSH_DEPTH = 0.25
-- Look north (+z), level, so +x (east) is on the right of the screen
local LOOK_PITCH = 0
local LOOK_YAW = 0
local START_POS = vector.new(0, 0, 0)

-- Collision box: narrower than a node, bottom on the node center line below
local HALF_WIDTH = 0.3
local BOX_BOTTOM = -0.5
local BOX_TOP = 0
-- How far past the box a solid node still counts as touching
local TOUCH_DISTANCE = 0.08
-- Horizontal foot offset for the ground check
local FOOT_OFFSET = 0.4

-- Opposite key pairs: horizontal first, then vertical
local KEYS = {
	{
		{key = "left",  dir = vector.new(-1, 0, 0)},
		{key = "right", dir = vector.new(1, 0, 0)},
	},
	{
		{key = "up",   dir = vector.new(0, 1, 0)},
		{key = "down", dir = vector.new(0, -1, 0)},
	},
}

-- Model nose points to -x at yaw 0
local TURN_SPEED = 15
local WHEEL_RADIUS = 1.5 / 16
-- Nozzle offsets from the machine origin at yaw 0 (the tail is +x)
local NOZZLES = {vector.new(0.22, -0.31, 0.31), vector.new(0.22, -0.31, -0.31)}
local EXHAUST_TEXTURE = {
	name = "st_machine_exhaust.png",
	blend = "alpha",
	scale_tween = {1, 2.2},
}

local WHEELS = {"wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"}
-- Position changes bigger than this in one step are teleports, not rolling
local MAX_ROLL_STEP = 1

local sessions = {}

local function fill(color)
	return "[fill:16x16:" .. color
end

-- One texture per mesh in the glb
local MODEL_MESH_COUNT = 47

local function model_textures()
	local textures = {}
	for i = 1, MODEL_MESH_COUNT do
		textures[i] = fill("#c04040")
	end
	return textures
end

core.register_entity("st_machine:machine", {
	initial_properties = {
		visual = "mesh",
		mesh = "digger1.glb",
		visual_size = {x = 10, y = 10, z = 10},
		textures = model_textures(),
		physical = true,
		collide_with_objects = false,
		collisionbox = {-HALF_WIDTH, BOX_BOTTOM, -HALF_WIDTH, HALF_WIDTH, BOX_TOP, HALF_WIDTH},
		-- Light is sampled at box corners, which end up inside solid nodes while digging
		glow = 10,
		pointable = false,
		static_save = false,
	},
})

core.register_entity("st_machine:rig", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.1, y = 0.1, z = 0.1},
		is_visible = false,
		physical = false,
		pointable = false,
		static_save = false,
	},
})

local function node_def(pos)
	local node = core.get_node(pos)
	if node.name == "ignore" then
		return nil
	end
	return core.registered_nodes[node.name]
end

local function approach(value, target, step)
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

local function held_entries(control)
	local held = {}
	for _, pair in ipairs(KEYS) do
		core.log("warning", "[loop-debug] held_entries iter")
		local a, b = control[pair[1].key], control[pair[2].key]
		if a and not b then
			held[#held + 1] = pair[1]
		elseif b and not a then
			held[#held + 1] = pair[2]
		end
	end
	core.log("warning", "[loop-debug] held_entries done")
	return held
end

local function grounded(pos)
	for _, dx in ipairs({-FOOT_OFFSET, FOOT_OFFSET}) do
		core.log("warning", "[loop-debug] grounded iter")
		local def = node_def(vector.round(vector.new(
			pos.x + dx, pos.y + BOX_BOTTOM - TOUCH_DISTANCE, pos.z)))
		if def and def.walkable then
			return true
		end
	end
	core.log("warning", "[loop-debug] grounded done")
	return false
end

-- "free": nothing solid in that direction, "dig": diggable node touching,
-- "blocked": anything else (undiggable, unloaded, or sideways without floor)
local function classify(pos, entry, on_ground, can_dig_up)
	local dir = entry.dir
	local reach = dir.y < 0 and -BOX_BOTTOM or (dir.y > 0 and BOX_TOP or HALF_WIDTH)
	local target = vector.round(vector.offset(pos,
		dir.x * (reach + TOUCH_DISTANCE), dir.y * (reach + TOUCH_DISTANCE), 0))
	local def = node_def(target)
	if not def then
		return "blocked"
	elseif not def.walkable then
		return "free"
	elseif def.diggable == false or (dir.y == 0 and not on_ground)
			or (dir.y > 0 and not can_dig_up) then
		return "blocked"
	end
	return "dig", target
end

local function start_dig(session, pick, pos, align_x)
	session.dig = {
		entry = pick.entry, target = pick.target, time = 0,
		anchor = vector.new(align_x or pos.x, pos.y, pos.z),
	}
	session.obj:set_properties({physical = false})
	session.obj:set_velocity(vector.zero())
	session.obj:set_acceleration(vector.zero())
	session.obj:set_pos(session.dig.anchor)
end

-- Back to normal physics; the machine glides home unless the node is gone
local function end_dig(session, keep_pos)
	if not keep_pos then
		session.obj:move_to(session.dig.anchor, true)
	end
	session.dig = nil
	session.obj:set_properties({physical = true})
end

-- Nodes may define st_cargo_drop(pos) returning {item = count}; no field means no drop
local function take_node(pos, player)
	local def = node_def(pos)
	local drop = def and def.st_cargo_drop and def.st_cargo_drop(pos)
	core.remove_node(pos)
	for item, count in pairs(drop or {}) do
		core.log("warning", "[loop-debug] take_node drop iter")
		cargo.add(player, item, count)
	end
	core.log("warning", "[loop-debug] take_node drop done")
	return true
end

local function dig_step(session, player, pick, dtime)
	local dig = session.dig
	dig.time = dig.time + dtime
	local hardness = (node_def(pick.target).st_hardness or DEFAULT_HARDNESS)
		/ stats.get(player).dig_speed
	if dig.time >= hardness then
		end_dig(session, take_node(pick.target, player))
	else
		local push = PUSH_DEPTH * dig.time / hardness
		session.obj:move_to(vector.add(dig.anchor, vector.multiply(dig.entry.dir, push)), true)
	end
end

local function control_step(session, player, pos, control, dtime)
	local dig = session.dig
	local my_stats = stats.get(player)
	local class_pos = dig and dig.anchor or pos
	local on_ground = grounded(class_pos)
	local free, digs = false, {}
	for _, entry in ipairs(held_entries(control)) do
		core.log("warning", "[loop-debug] control_step entry iter")
		local kind, target = classify(class_pos, entry, on_ground, my_stats.can_dig_up)
		if kind == "free" then
			free = true
		elseif kind == "dig" then
			digs[#digs + 1] = {entry = entry, target = target}
		end
	end
	core.log("warning", "[loop-debug] control_step entries done")

	if dig then
		local pick
		for _, candidate in ipairs(digs) do
			core.log("warning", "[loop-debug] control_step candidate iter")
			if candidate.entry == dig.entry then
				pick = candidate
			end
		end
		core.log("warning", "[loop-debug] control_step candidates done")
		if free or not pick or pick.target ~= dig.target then
			end_dig(session, false)
		else
			dig_step(session, player, pick, dtime)
			return
		end
	end

	local pick = not free and digs[1] or nil
	local align_x
	if pick and pick.entry.dir.y ~= 0 then
		align_x = math.floor(pos.x + 0.5)
	end
	if pick and (not align_x or math.abs(pos.x - align_x) <= ALIGN_TOLERANCE) then
		start_dig(session, pick, pos, align_x)
		return
	end

	local vel = session.obj:get_velocity()
	local target_vx = ((control.right and 1 or 0) - (control.left and 1 or 0)) * my_stats.move_speed
	if align_x then
		target_vx = math.max(-ALIGN_SPEED, math.min(ALIGN_SPEED, (align_x - pos.x) * ALIGN_RATE))
	end
	vel.x = approach(vel.x, target_vx, ACCEL * dtime)
	local accel_y = -session.gravity
	if control.up and not control.down then
		local climb = my_stats.thrust / (1 + cargo.weight(player) * CARGO_DRAG)
		vel.y = approach(vel.y, climb, ACCEL * dtime)
		accel_y = 0
	end
	vel.y = math.max(vel.y, -MAX_FALL_SPEED)
	vel.z = 0
	session.obj:set_velocity(vel)
	session.obj:set_acceleration(vector.new(0, accel_y, 0))
end

local EXHAUST_INTERVAL = 0.1
local EXHAUST_PER_NOZZLE = 3

local function spawn_exhaust(session, dtime)
	session.exhaust_timer = (session.exhaust_timer or 0) + dtime
	if session.exhaust_timer < EXHAUST_INTERVAL then
		return
	end
	session.exhaust_timer = session.exhaust_timer - EXHAUST_INTERVAL
	local pos = session.obj:get_pos()
	for _, nozzle in ipairs(NOZZLES) do
		core.log("warning", "[loop-debug] spawn_exhaust nozzle iter")
		local origin = vector.add(pos, vector.rotate(nozzle, vector.new(0, session.yaw, 0)))
		for _ = 1, EXHAUST_PER_NOZZLE do
			core.log("warning", "[loop-debug] spawn_exhaust particle iter")
			local lifetime = 0.4 + math.random() * 0.4
			core.add_particle({
				pos = vector.offset(origin, math.random() * 0.06 - 0.03, 0, math.random() * 0.06 - 0.03),
				velocity = vector.new(math.random() * 0.6 - 0.3, -2.5 - math.random() * 1.5, math.random() * 0.6 - 0.3),
				expirationtime = lifetime,
				size = 0.75 + math.random() * 0.45,
				texture = EXHAUST_TEXTURE,
				animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = lifetime + 0.1},
				glow = 12,
			})
		end
		core.log("warning", "[loop-debug] spawn_exhaust particles done")
	end
	core.log("warning", "[loop-debug] spawn_exhaust nozzles done")
end

local function animate(session, control, dtime)
	local obj = session.obj

	if control.up then
		spawn_exhaust(session, dtime)
	end

	if control.right and not control.left then
		session.target_yaw = math.pi
	elseif control.left and not control.right then
		session.target_yaw = 0
	end
	session.yaw = approach(session.yaw, session.target_yaw, TURN_SPEED * dtime)
	obj:set_yaw(session.yaw)

	local x = obj:get_pos().x
	local moved = session.last_x and x - session.last_x or 0
	session.last_x = x
	if math.abs(moved) < MAX_ROLL_STEP then
		local forward = moved * -math.cos(session.yaw)
		session.wheel_angle = (session.wheel_angle + forward / WHEEL_RADIUS) % (2 * math.pi)
	end
	for _, bone in ipairs(WHEELS) do
		core.log("warning", "[loop-debug] animate bone iter " .. bone)
		obj:set_bone_override(bone, {rotation = {vec = vector.new(0, 0, session.wheel_angle)}})
	end
	core.log("warning", "[loop-debug] animate bones done")
end

local function start(player, pos)
	local obj = core.add_entity(pos, "st_machine:machine")
	if not obj then
		return
	end
	-- Lift the camera by the eye height so the view is centered on the machine
	local eye_height = player:get_properties().eye_height
	local cam_offset = vector.new(0, -eye_height, -CAM_START_DISTANCE)
	-- The client camera ignores the attach offset, so attach to a separate rig
	local rig = core.add_entity(vector.add(pos, cam_offset), "st_machine:rig")
	if not rig then
		obj:remove()
		return
	end
	player:set_attach(rig)
	player:set_camera({mode = "first"})
	player:set_properties({zoom_fov = 0})
	player:set_look_vertical(LOOK_PITCH)
	player:set_look_horizontal(LOOK_YAW)
	player:hud_set_flags({wielditem = false, crosshair = false})
	player:set_sky({fog = {fog_distance = VIEW_DISTANCE, fog_start = FOG_START}})
	sessions[player:get_player_name()] = {
		obj = obj, rig = rig, cam_offset = cam_offset,
		gravity = DEFAULT_GRAVITY, dig = nil,
		yaw = 0, target_yaw = 0, wheel_angle = 0,
	}
end

core.register_globalstep(function(dtime)
	for name, session in pairs(sessions) do
		core.log("warning", "[loop-debug] globalstep session iter")
		local player = core.get_player_by_name(name)
		local pos = session.obj:get_pos()
		local rig_pos = session.rig:get_pos()
		if not player or not pos or not rig_pos then
			session.rig:remove()
			session.obj:remove()
			sessions[name] = nil
		else

			session.cam_offset.z = approach(
				session.cam_offset.z, -CAM_DISTANCE, CAM_PULLBACK_SPEED * dtime)
			local cam_target = vector.add(pos, session.cam_offset)
			local offset = vector.subtract(cam_target, rig_pos)
			session.rig:set_velocity(vector.multiply(offset, math.min(FOLLOW_SPEED, 1 / dtime)))

			local control = player:get_player_control()
			control_step(session, player, pos, control, dtime)
			animate(session, control, dtime)
		end
	end
	core.log("warning", "[loop-debug] globalstep sessions done")
end)

local SAVED_POS_KEY = "st_machine:pos"

local function saved_pos(player)
	return core.string_to_pos(player:get_meta():get_string(SAVED_POS_KEY)) or START_POS
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local session = sessions[name]
	stats.forget(player)
	cargo.forget(player)
	if session then
		local pos = session.dig and session.dig.anchor or session.obj:get_pos()
		if pos then
			player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(pos, 3))
		end
		session.rig:remove()
		session.obj:remove()
		sessions[name] = nil
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local radius = vector.new(16, 16, 16)
	local pos = saved_pos(player)
	-- Wait for the map around the start to exist before spawning the machine
	core.emerge_area(vector.subtract(pos, radius), vector.add(pos, radius),
		function(_, _, calls_remaining)
			if calls_remaining > 0 then
				return
			end
			local joined = core.get_player_by_name(name)
			if joined and not sessions[name] then
				start(joined, pos)
			end
		end)
end)

-- The builtin clear removes the machine and camera rig; only clear other entities
core.override_chatcommand("clearobjects", {
	func = function(name, param)
		if param ~= "quick" and param ~= "full" then
			return false
		end
		local doomed = {}
		for _, entity in pairs(core.luaentities) do
			if entity.name:sub(1, #"st_machine:") ~= "st_machine:" then
				doomed[#doomed + 1] = entity.object
			end
		end
		for _, obj in ipairs(doomed) do
			obj:remove()
		end
		core.log("action", name .. " clears objects (" .. #doomed .. " loaded, skipping st_machine).")
		return true, "Cleared " .. #doomed .. " loaded objects."
	end,
})
