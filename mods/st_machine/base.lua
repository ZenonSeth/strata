local stats = st_machine.stats
local cargo = st_machine.cargo
local fuel = st_machine.fuel
local hull = st_machine.hull

local ENGINE_GAIN = 0.8
local MIN_IMPACT_SPEED = st_utils.constants.min_impact_speed
local IMPACT_GAIN_MIN, IMPACT_GAIN_MAX = 0.4, 1.0
st_audio.sfx.register("vehicle_tire_impact", {
	sound = "st_machine_vehicle_tire_impact", category = "vehicle", max_hear_distance = 32,
})

-- Dig sound per stratum (or "dirt"/"surface" for the top rows)
local DUG_SOUND = {
	dirt = "soil", surface = "soil", topsoil = "soil",
	clay = "gravel", sandstone = "gravel",
	limestone = "rock", shale = "rock", slate = "rock", marble = "rock", schist = "rock",
	gneiss = "hardrock", basalt = "hardrock", granite = "hardrock", quartzite = "hardrock",
	eclogite = "hardrock", peridotite = "hardrock", core = "hardrock",
}
for _, kind in ipairs({"soil", "gravel", "rock", "hardrock"}) do
	st_audio.sfx.register("dug_" .. kind, {
		sound = "st_machine_dug_" .. kind, max_hear_distance = 32, pitch = kind == "gravel" and 0.5 or nil,
	})
end

local function dug_sound(node_name)
	local host = node_name:match("_in_(%a+)$")
	if not host then
		local def = core.registered_nodes[node_name]
		host = ((def and def.st_base) or node_name):match("^st_nodes:(%a+)")
	end
	return DUG_SOUND[host or ""]
end

-- Out of fuel: engine stays on idle, no burner
local function engine_sound(session, player, control)
	if session.muted then
		return
	end
	local sfx = st_audio.sfx
	local climbing = control.up and not control.down and not session.liquid
	local has_fuel = not fuel.is_empty(player)
	local engine = "engine_idle"
	if has_fuel then
		if session.dig then
			engine = "engine_rev"
		elseif climbing or control.left ~= control.right then
			engine = "engine_mid"
		end
	end
	sfx.start_loop(player, "engine", engine)
	if has_fuel and climbing and not session.dig then
		local propeller = stats.get_level(player, "thrusters").kind == "propeller"
		sfx.start_loop(player, "burner", propeller and "helicopter" or "burner")
	else
		sfx.stop_loop(player, "burner")
	end
end

local function stop_engine_sound(player)
	st_audio.sfx.stop_loop(player, "engine")
	st_audio.sfx.stop_loop(player, "burner")
end

local CAM_DISTANCE = 12
local CAM_START_DISTANCE = 4
-- The camera starts CAM_START_DISTANCE away and backs off to CAM_DISTANCE at this speed (nodes/s)
local CAM_PULLBACK_SPEED = 2
local VIEW_DISTANCE = 80
-- Fraction of the view distance where fog starts
local FOG_START = 0.4
local FOLLOW_SPEED = 8
-- How fast the machine reaches its target speed (nodes/s^2)
local ACCEL = 50
-- Thrust acceleration is THRUST_ACCEL / (1 + RATED_DRAG * cargo weight / thrust_rating); gravity still pulls against it
local THRUST_ACCEL = 65
-- At the rated weight the net climb accel is 10% of the empty-hold one
local RATED_DRAG = 2.25
local MAX_FALL_SPEED = st_utils.constants.max_fall_speed
local LIQUID = st_utils.constants.liquid
-- Easing onto the dig row/column
local ALIGN_SPEED = 3
local ALIGN_RATE = 10
local ALIGN_TOLERANCE = 0.03
-- Nodes per second squared; per session so it can differ per planet later
local DEFAULT_GRAVITY = 15
-- Seconds to dig a node unless it defines st_hardness
local DEFAULT_HARDNESS = 1
-- How far (in nodes) the machine bites into the node by the time the dig finishes
local PUSH_DEPTH = 0.25
-- Look north (+z), level, so +x (east) is on the right of the screen
local LOOK_PITCH = 0
local LOOK_YAW = 0
local LOOK_RANGE = math.rad(30)
local SURFACE_Y = st_utils.constants.surface_y
local SLICE_Z = st_utils.constants.slice_z
-- In front of the shop; the machine rests on the ground node, so its centre is one node above it
local START_POS = vector.new(st_utils.constants.shop_x, SURFACE_Y + 1, SLICE_Z)
-- Machine glow in full daylight; it scales down with the world light level
local MAX_GLOW = 10

st_hud.register_strip("st_machine:top_bar", {height = 44, color = "#00000080"})

local DEPTH_HUD = "st_machine:depth"
local DEPTH_INTERVAL = 0.5
st_hud.register_text(DEPTH_HUD, {
	position = {x = 0.5, y = 0}, offset = {x = -120, y = 22}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", mono = true,
})

local SPEED_HUD = "st_machine:vertical_speed"
st_hud.register_text(SPEED_HUD, {
	position = {x = 0.5, y = 0}, offset = {x = 120, y = 22}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", mono = true,
})

local function update_speed(player, vel_y)
	-- Rounded to a tenth; "+0.0" is shown as "0.0" so it never flickers between signs
	local speed = math.floor(vel_y * 10 + 0.5) / 10
	st_hud.set_text(player, SPEED_HUD, string.format(speed > 0 and "V: +%.1f m/s" or "V: %.1f m/s", speed + 0))
end

local PAD_HUD = "st_machine:pad"
st_hud.register_text(PAD_HUD, {
	position = {x = 0.5, y = 0.5}, offset = {x = 0, y = -90}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", background = {},
})

local depth_listeners = {}
local last_depth = {}

-- fn(player, depth, old_depth) on a whole-metre depth change; depth is below the start (negative above)
function st_machine.register_on_depth_change(fn)
	depth_listeners[#depth_listeners + 1] = fn
end

local function update_depth(player, pos)
	local y = math.floor(pos.y + 0.5) - START_POS.y
	local label = y > 0 and "Height" or "Depth"
	st_hud.set_text(player, DEPTH_HUD, string.format("%s: %dm", label, y))
	local name = player:get_player_name()
	local depth, old = -y, last_depth[name]
	if depth ~= old then
		last_depth[name] = depth
		local playing = st_audio.music.current(player)
		if depth >= 10 then
			if playing ~= "underground" then
				st_audio.music.play(player, "underground", function()
					return (last_depth[name] or 0) >= 10
				end)
			end
		elseif depth > 1 and playing == "foot" then
			st_audio.music.stop(player)
		end
		for _, fn in ipairs(depth_listeners) do
			fn(player, depth, old)
		end
	end
end

local dig_listeners = {}

-- fn(player, pos, node_name, method) for every node destroyed for the player, even if the hold is full
function st_machine.register_on_dig(fn)
	dig_listeners[#dig_listeners + 1] = fn
end

function st_machine.notify_dig(player, pos, node_name, method)
	for _, fn in ipairs(dig_listeners) do
		fn(player, pos, node_name, method)
	end
end

-- Collision box: narrower than a node, bottom on the node center line below
local HALF_WIDTH = 0.3
local BOX_BOTTOM = -0.5
local BOX_TOP = 0
-- How far past the box a solid node still counts as touching
local TOUCH_DISTANCE = 0.08

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
-- Drills pitch from sideways (0) to straight down (+) or up (-) at this speed (rad/s)
local DRILL_TURN_SPEED = 6
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

-- Silences the engine and burner until unmuted (e.g. under a fullscreen screen); the next step restarts them
function st_machine.set_muted(player, muted)
	local session = sessions[player:get_player_name()]
	if session then
		session.muted = muted or nil
	end
	if muted then
		stop_engine_sound(player)
	end
end

local colors = st_machine.colors
local color_listeners = {}

-- Entity textures for the player's chosen colors (the defaults without a player)
function st_machine.model_textures(player)
	return colors.textures(colors.get(player))
end

function st_machine.get_colors(player)
	return colors.get(player)
end

-- fn(player, textures) runs after a color changes, so display models can follow
function st_machine.register_on_colors_changed(fn)
	color_listeners[#color_listeners + 1] = fn
end

-- key is "frame" or "panel", hex is "#rrggbb"; updates the machine now and the display models via listeners
function st_machine.set_color(player, key, hex)
	if not colors.set(player, key, hex) then
		return false
	end
	local textures = st_machine.model_textures(player)
	local session = sessions[player:get_player_name()]
	if session and session.obj:is_valid() then
		session.obj:set_properties({textures = textures})
	end
	for _, fn in ipairs(color_listeners) do
		fn(player, textures)
	end
	return true
end

core.register_entity("st_machine:machine", {
	initial_properties = {
		visual = "mesh",
		mesh = "digger1.glb",
		visual_size = {x = 10, y = 10, z = 10},
		textures = st_machine.model_textures(),
		physical = true,
		collide_with_objects = false,
		collisionbox = {-HALF_WIDTH, BOX_BOTTOM, -HALF_WIDTH, HALF_WIDTH, BOX_TOP, HALF_WIDTH},
		-- Light is sampled at box corners, which end up inside solid nodes while digging;
		-- the glow tracks the world light level (see the globalstep)
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
		local a, b = control[pair[1].key], control[pair[2].key]
		if a and not b then
			held[#held + 1] = pair[1]
		elseif b and not a then
			held[#held + 1] = pair[2]
		end
	end
	return held
end

-- Floor under the node column the machine is centered in
local function grounded(pos)
	local def = node_def(vector.round(vector.new(
		pos.x, pos.y + BOX_BOTTOM - TOUCH_DISTANCE, pos.z)))
	return def ~= nil and def.walkable == true
end

-- "free": nothing solid in that direction, "dig": diggable node touching,
-- "blocked": anything else (undiggable, above the drill tier, unloaded, or sideways without floor)
local function classify(pos, entry, on_ground, can_dig_up, drill_tier)
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
			or (dir.y > 0 and not can_dig_up) or (def.st_tier or 0) > drill_tier then
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

-- Nodes with st_material and st_yield add that much of the item to the hold; what does not fit is lost
local function take_node(pos, player)
	local def = node_def(pos)
	local item = def and def.st_material
	local node_name = core.get_node(pos).name
	core.remove_node(pos)
	st_nodes.refresh_shapes(pos)
	local kind = dug_sound(node_name)
	if kind then
		st_audio.sfx.play("dug_" .. kind, {player = player})
	end
	st_machine.notify_dig(player, pos, node_name, "drill")
	if item then
		cargo.add(player, item, def.st_yield or 1)
	end
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

local FUEL = st_utils.constants.fuel

local function burn_fuel(player, multiplier, dtime)
	fuel.remove(player, FUEL.burn_per_second * multiplier * stats.get(player).fuel_use * dtime)
end

local function control_step(session, player, pos, control, dtime)
	local dig = session.dig
	local my_stats = stats.get(player)
	local class_pos = dig and dig.anchor or pos
	local on_ground = grounded(class_pos)
	local free, digs = false, {}
	for _, entry in ipairs(held_entries(control)) do
		local kind, target = classify(class_pos, entry, on_ground, my_stats.can_dig_up, my_stats.drill_tier)
		if kind == "free" then
			free = true
		elseif kind == "dig" and not fuel.is_empty(player) then
			digs[#digs + 1] = {entry = entry, target = target}
		end
	end

	if dig then
		local pick
		for _, candidate in ipairs(digs) do
			if candidate.entry == dig.entry then
				pick = candidate
			end
		end
		if free or not pick or pick.target ~= dig.target then
			end_dig(session, false)
		else
			burn_fuel(player, FUEL.dig_mult, dtime)
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
	local speed_mult = fuel.is_empty(player) and FUEL.empty_speed_mult or 1
	local top_thrust = my_stats.thrust * speed_mult
	if session.liquid then
		speed_mult = speed_mult * LIQUID.speed_mult
	end
	local target_vx = ((control.right and 1 or 0) - (control.left and 1 or 0)) * my_stats.move_speed * speed_mult
	if align_x then
		target_vx = math.max(-ALIGN_SPEED, math.min(ALIGN_SPEED, (align_x - pos.x) * ALIGN_RATE))
	end
	vel.x = approach(vel.x, target_vx, ACCEL * dtime)
	local accel_y = -session.gravity
	local climbing = control.up and not control.down and not session.liquid
	if climbing then
		burn_fuel(player, FUEL.climb_mult, dtime)
	elseif control.left ~= control.right then
		burn_fuel(player, 1, dtime)
	end
	if climbing then
		accel_y = THRUST_ACCEL / (1 + RATED_DRAG * cargo.weight(player) / my_stats.thrust_rating) - session.gravity
		if vel.y > top_thrust then
			vel.y = approach(vel.y, top_thrust, ACCEL * dtime)
			accel_y = 0
		else
			-- The engine integrates accel between steps, so stop it at the cap instead of overshooting
			accel_y = math.min(accel_y, (top_thrust - vel.y) / dtime)
		end
	end
	vel.y = math.max(vel.y, -(session.liquid and LIQUID.max_fall_speed or MAX_FALL_SPEED))
	vel.z = 0
	session.obj:set_velocity(vel)
	session.obj:set_acceleration(vector.new(0, accel_y, 0))
end

local EXHAUST_INTERVAL = 0.1
-- Per thruster kind (see thrusters.lua): particles per nozzle per burst (full tank, empty tank), downward speed, size and lifetime
-- as {minimum, random extra}; spread is the random sideways offset (nodes) of the spawn point; static = a single-frame texture
local EXHAUST_PROFILES = {
	propeller = {
		count = 2, empty_count = 0, speed = {3, 2}, size = {0.5, 0.3}, life = {0.12, 0.12}, spread = 0.1, static = true,
		texture = {name = "st_machine_wind.png", blend = "alpha"},
	},
	jet = {count = 3, empty_count = 1, speed = {2.5, 1.5}, size = {0.75, 0.45}, life = {0.4, 0.4}, spread = 0.03,
		texture = EXHAUST_TEXTURE},
	rocket = {
		count = 6, empty_count = 1, speed = {5, 3}, size = {1.2, 1}, life = {0.5, 0.5}, spread = 0.03,
		texture = {name = "st_machine_exhaust.png^[multiply:#ffa060", blend = "alpha", scale_tween = {1, 2.2}},
	},
}

local function spawn_exhaust(session, player, dtime)
	local profile = EXHAUST_PROFILES[stats.get_level(player, "thrusters").kind]
	if not profile then
		return
	end
	session.exhaust_timer = (session.exhaust_timer or 0) + dtime
	if session.exhaust_timer < EXHAUST_INTERVAL then
		return
	end
	session.exhaust_timer = session.exhaust_timer - EXHAUST_INTERVAL
	local pos = session.obj:get_pos()
	local count = fuel.is_empty(player) and profile.empty_count or profile.count
	for _, nozzle in ipairs(NOZZLES) do
		local origin = vector.add(pos, vector.rotate(nozzle, vector.new(0, session.yaw, 0)))
		for _ = 1, count do
			local lifetime = profile.life[1] + math.random() * profile.life[2]
			core.add_particle({
				pos = vector.offset(origin, (math.random() - 0.5) * 2 * profile.spread, 0, (math.random() - 0.5) * 2 * profile.spread),
				velocity = vector.new(math.random() * 0.6 - 0.3, -profile.speed[1] - math.random() * profile.speed[2],
					math.random() * 0.6 - 0.3),
				expirationtime = lifetime,
				size = profile.size[1] + math.random() * profile.size[2],
				texture = profile.texture,
				animation = not profile.static and
					{type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = lifetime + 0.1} or nil,
				glow = 12,
				collisiondetection = true,
				collision_removal = true,
			})
		end
	end
end

-- Landing speed is the faster of this and the previous step's fall: the ground check trips just before contact
local function impact(session, player, pos, vel_y)
	local on_ground = grounded(pos)
	local was_grounded = session.was_grounded
	local fall = math.max(-vel_y, -(session.prev_vel_y or 0))
	session.was_grounded = on_ground
	session.prev_vel_y = vel_y
	if was_grounded ~= false or not on_ground or fall < MIN_IMPACT_SPEED then
		return
	end
	local t = st_utils.impact_scale(fall)
	st_audio.sfx.play("vehicle_tire_impact", {
		pos = pos, gain = IMPACT_GAIN_MIN + (IMPACT_GAIN_MAX - IMPACT_GAIN_MIN) * t,
	})
	hull.damage(player, st_utils.impact_damage(fall))
end
for _, name in ipairs({"engine_idle", "engine_mid", "engine_rev", "burner", "helicopter"}) do
	st_audio.sfx.register(name, {sound = "st_machine_" .. name, category = "vehicle", gain = ENGINE_GAIN})
end

local function animate(session, player, control, dtime)
	local obj = session.obj

	engine_sound(session, player, control)
	impact(session, player, obj:get_pos(), obj:get_velocity().y)
	-- A hard landing can destroy the machine
	if session.destroyed then
		return
	end
	if control.up and not session.liquid then
		spawn_exhaust(session, player, dtime)
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
	local driving = control.left ~= control.right and grounded(obj:get_pos())
	if driving and math.abs(moved) < MAX_ROLL_STEP then
		local forward = moved * -math.cos(session.yaw)
		session.wheel_angle = (session.wheel_angle + forward / WHEEL_RADIUS) % (2 * math.pi)
	end
	local drill_target = 0
	if control.down and not control.up then
		drill_target = math.pi / 2
	elseif control.up and not control.down and stats.get(player).can_dig_up then
		drill_target = -math.pi / 2
	end
	session.drill_pitch = approach(session.drill_pitch or 0, drill_target, DRILL_TURN_SPEED * dtime)
	obj:set_bone_override("drills_combined", {
		rotation = {vec = vector.new(0, 0, session.drill_pitch), absolute = true},
	})
	for _, bone in ipairs(WHEELS) do
		obj:set_bone_override(bone, {rotation = {vec = vector.new(0, 0, session.wheel_angle), absolute = true}})
	end
end

local function reset_look(player)
	player:set_look_vertical(LOOK_PITCH)
	player:set_look_horizontal(LOOK_YAW)
end

-- Put the player in the camera rig and apply the vehicle view
local function board(player, session)
	player:set_attach(session.rig)
	player:set_camera({mode = "first"})
	-- player:set_properties({zoom_fov = 0})
	reset_look(player)
	player:hud_set_flags({wielditem = false, crosshair = false, hotbar = true})
	fuel.refresh(player)
	hull.refresh(player)
	st_machine.cargo.refresh(player)
	update_depth(player, session.obj:get_pos())
	player:set_sky({fog = {fog_distance = VIEW_DISTANCE, fog_start = FOG_START}})
end

local function start(player, pos)
	local obj = core.add_entity(pos, "st_machine:machine")
	if not obj then
		return
	end
	obj:set_properties({textures = st_machine.model_textures(player)})
	-- Lift the camera by the eye height so the view is centered on the machine
	local eye_height = player:get_properties().eye_height
	local cam_offset = vector.new(0, -eye_height, -CAM_START_DISTANCE)
	-- The client camera ignores the attach offset, so attach to a separate rig
	local rig = core.add_entity(vector.add(pos, cam_offset), "st_machine:rig")
	if not rig then
		obj:remove()
		return
	end
	local session = {
		obj = obj, rig = rig, cam_offset = cam_offset,
		gravity = DEFAULT_GRAVITY, dig = nil, depth_timer = 0, save_timer = 0,
		yaw = 0, target_yaw = 0, wheel_angle = 0, last_pos = pos,
	}
	sessions[player:get_player_name()] = session
	board(player, session)
end

local SAVED_POS_KEY = "st_machine:pos"
local SAVE_INTERVAL = 1

local function saved_pos(player)
	return core.string_to_pos(player:get_meta():get_string(SAVED_POS_KEY)) or START_POS
end

-- player name -> token of the spawn waiting for the map; a newer spawn or leaving
-- the mode cancels it
local pending = {}

-- Wait for the map around pos to exist before spawning the machine
local function spawn_at(name, pos)
	local token = {}
	pending[name] = token
	local radius = vector.new(16, 16, 16)
	core.emerge_area(vector.subtract(pos, radius), vector.add(pos, radius),
		function(_, _, calls_remaining)
			if calls_remaining > 0 or pending[name] ~= token then
				return
			end
			pending[name] = nil
			local joined = core.get_player_by_name(name)
			if joined and not sessions[name] and st_mode.get(joined) == "vehicle" then
				start(joined, pos)
			end
		end)
end

local function clamp_look(player)
	local yaw = player:get_look_horizontal()
	local dyaw = (yaw - LOOK_YAW + math.pi) % (2 * math.pi) - math.pi
	if math.abs(dyaw) > LOOK_RANGE then
		player:set_look_horizontal(LOOK_YAW + math.max(-LOOK_RANGE, math.min(LOOK_RANGE, dyaw)))
	end
	local pitch = player:get_look_vertical()
	if math.abs(pitch - LOOK_PITCH) > LOOK_RANGE then
		player:set_look_vertical(LOOK_PITCH + math.max(-LOOK_RANGE, math.min(LOOK_RANGE, pitch - LOOK_PITCH)))
	end
end

-- Shows the prompt of the active pad the machine stands on; a fresh Down press uses it.
-- Returns true if that left vehicle mode.
local function pad_step(session, player, pos, control)
	local pad = not session.dig and st_pads.get(vector.round(vector.new(
		pos.x, pos.y + BOX_BOTTOM - TOUCH_DISTANCE, pos.z))) or nil
	local label = pad and ("[Down] " .. pad.label) or ""
	if label ~= session.pad_label then
		session.pad_label = label
		st_hud.set_text(player, PAD_HUD, label)
	end
	local pressed = control.down and not session.down_held
	session.down_held = control.down
	if pad and pressed then
		pad.on_use(player)
		return st_mode.get(player) ~= "vehicle"
	end
	return false
end

local function vehicle_step(player, dtime)
	local name = player:get_player_name()
	local session = sessions[name]
	if not session then
		return
	end
	if session.destroyed then
		return
	end
	local pos = session.obj:get_pos()
	local rig_pos = session.rig:get_pos()
	if not pos or not rig_pos then
		-- The machine or rig is gone (e.g. its block unloaded): start over where it was
		session.rig:remove()
		session.obj:remove()
		sessions[name] = nil
		player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(session.last_pos, 3))
		spawn_at(name, session.last_pos)
		return
	end
	session.last_pos = pos

	session.cam_offset.z = approach(
		session.cam_offset.z, -CAM_DISTANCE, CAM_PULLBACK_SPEED * dtime)
	local cam_target = vector.add(pos, session.cam_offset)
	local offset = vector.subtract(cam_target, rig_pos)
	session.rig:set_velocity(vector.multiply(offset, math.min(FOLLOW_SPEED, 1 / dtime)))

	clamp_look(player)
	local control = player:get_player_control()
	local light = stats.get(player)
	local ratio = st_environment.update(
		player, pos.y, light.light_fade_end, light.vignette_max, light.light_min)
	local glow = math.floor(ratio * MAX_GLOW + 0.5)
	if session.glow ~= glow then
		session.glow = glow
		session.obj:set_properties({glow = glow})
	end
	update_speed(player, session.obj:get_velocity().y)
	session.depth_timer = session.depth_timer + dtime
	if session.depth_timer >= DEPTH_INTERVAL then
		session.depth_timer = session.depth_timer - DEPTH_INTERVAL
		update_depth(player, pos)
	end
	session.save_timer = session.save_timer + dtime
	if session.save_timer >= SAVE_INTERVAL then
		session.save_timer = 0
		player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(pos, 3))
	end
	if pad_step(session, player, pos, control) then
		return
	end
	-- Liquid in the node the machine occupies; its damage_per_second hurts the hull
	local def = node_def(vector.round(pos))
	session.liquid = def and def.liquidtype and def.liquidtype ~= "none" and def or nil
	local damage = session.liquid and session.liquid.damage_per_second or 0
	if damage > 0 then
		hull.damage(player, damage * dtime)
		if session.destroyed then
			return
		end
	end
	control_step(session, player, pos, control, dtime)
	animate(session, player, control, dtime)
end

local EXPLOSION_PARTICLES = 60
local DEATH_FORM = "st_machine:death"
local DEATH_W, DEATH_H = 8, 4
local DEATH_BUTTON_W, DEATH_BUTTON_H = 3, 0.9

local function show_death_screen(player)
	-- Close whatever else is open (e.g. the inventory) so the death screen is the only window
	core.close_formspec(player:get_player_name(), "")
	local fs = {
		st_gui.header(DEATH_W, DEATH_H, "Critical Hull Failure"),
		"allow_close[false]",
		("label[0.4,%g;%s]"):format(st_gui.CONTENT_Y + 0.4, "The machine has been destroyed."),
		("button[%g,%g;%g,%g;respawn;Respawn]"):format(
			(DEATH_W - DEATH_BUTTON_W) / 2, DEATH_H - DEATH_BUTTON_H - 0.4, DEATH_BUTTON_W, DEATH_BUTTON_H),
	}
	core.show_formspec(player:get_player_name(), DEATH_FORM, table.concat(fs))
end

-- The player driving this machine entity, or nil
function st_machine.owner(obj)
	for name, session in pairs(sessions) do
		if session.obj == obj then
			return core.get_player_by_name(name)
		end
	end
end

function st_machine.is_dead(player)
	local session = sessions[player:get_player_name()]
	return session ~= nil and session.destroyed == true
end

function st_machine.destroy(player)
	local name = player:get_player_name()
	local session = sessions[name]
	if (session and session.destroyed) or st_mode.get(player) ~= "vehicle" then
		return
	end
	-- The penalty is applied at once so it survives leaving during the death screen
	cargo.clear(player)
	stats.reset_upgrades(player)
	hull.set(player, stats.get(player).max_hull)
	fuel.set(player, stats.get(player).max_fuel / 2)
	player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(START_POS, 3))
	stop_engine_sound(player)
	if not session then
		spawn_at(name, START_POS)
		return
	end
	session.destroyed = true
	local pos = session.obj:get_pos()
	if pos then
		st_utils.puff(pos, EXPLOSION_PARTICLES, 1, EXHAUST_TEXTURE, true)
	end
	-- The camera rig stays so the view is frozen where the machine blew up
	session.obj:remove()
	session.rig:set_velocity(vector.zero())
	st_environment.set_player_lighting(player, {saturation = 0})
	show_death_screen(player)
end

local function respawn(player)
	local name = player:get_player_name()
	local session = sessions[name]
	if not session or not session.destroyed then
		return
	end
	session.rig:remove()
	sessions[name] = nil
	core.close_formspec(name, DEATH_FORM)
	local light = stats.get(player)
	st_environment.set_player_lighting(player)
	st_environment.update(player, START_POS.y, light.light_fade_end, light.vignette_max, light.light_min)
	spawn_at(name, START_POS)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= DEATH_FORM then
		return
	end
	if fields.respawn then
		respawn(player)
	elseif fields.quit and st_machine.is_dead(player) then
		show_death_screen(player)
	end
end)

local function discard(name)
	local session = sessions[name]
	if session then
		session.rig:remove()
		session.obj:remove()
		sessions[name] = nil
	end
end

st_mode.register_mode("vehicle", {
	on_enter = function(player)
		local name = player:get_player_name()
		local session = sessions[name]
		if session and not session.destroyed and session.obj:get_pos() and session.rig:get_pos() then
			session.cam_offset.z = -CAM_START_DISTANCE
			session.rig:set_pos(vector.add(session.obj:get_pos(), session.cam_offset))
			board(player, session)
			-- Again next step: the client's own look can overwrite the first one when boarding mid-click
			core.after(0, function()
				if player:is_valid() and st_mode.get(player) == "vehicle" then
					reset_look(player)
				end
			end)
			return
		end
		-- The parked machine is gone (e.g. its block unloaded): start over where it was
		discard(name)
		spawn_at(name, saved_pos(player))
	end,
	-- The machine and camera rig stay where they are while the player is out
	on_exit = function(player)
		local name = player:get_player_name()
		pending[name] = nil
		stop_engine_sound(player)
		local session = sessions[name]
		if not session then
			return
		end
		session.muted = nil
		if session.destroyed then
			discard(name)
			st_environment.set_player_lighting(player)
			core.close_formspec(name, DEATH_FORM)
			return
		end
		if session.dig then
			end_dig(session, false)
		end
		local pos = session.obj:get_pos() or session.last_pos
		session.last_pos = pos
		player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(pos, 3))
		session.obj:set_velocity(vector.zero())
		session.obj:set_acceleration(vector.new(0, -session.gravity, 0))
		session.rig:set_velocity(vector.zero())
		player:set_detach()
		player:set_pos(vector.offset(pos, 0, BOX_BOTTOM, 0))
	end,
	on_step = vehicle_step,
})

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local session = sessions[name]
	local pos = session and not session.destroyed and session.obj:get_pos()
	if pos then
		player:get_meta():set_string(SAVED_POS_KEY, core.pos_to_string(pos, 3))
	end
	pending[name] = nil
	last_depth[name] = nil
	discard(name)
	stats.forget(player)
	cargo.forget(player)
	fuel.forget(player)
	hull.forget(player)
end)

-- The builtin clear removes the machine and camera rig; only clear other entities (unless flagged keep_on_clear)
core.override_chatcommand("clearobjects", {
	func = function(name, param)
		if param ~= "quick" and param ~= "full" then
			return false
		end
		local doomed = {}
		for _, entity in pairs(core.luaentities) do
			if entity.name:sub(1, #"st_machine:") ~= "st_machine:" and not entity.keep_on_clear then
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
