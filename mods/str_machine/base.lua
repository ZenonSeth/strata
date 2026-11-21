local stats = str_machine.stats
local cargo = str_machine.cargo
local fuel = str_machine.fuel
local hull = str_machine.hull

local ENGINE_GAIN = 0.8
local MIN_IMPACT_SPEED = str_utils.constants.min_impact_speed
local IMPACT_GAIN_MIN, IMPACT_GAIN_MAX = 0.8, 1.0
-- Lava damage lands every step: one sizzle clip per this many seconds overlaps them without stacking
local LAVA_SIZZLE_INTERVAL = 0.6

local function sizzle(session, player)
	local now = core.get_us_time() / 1e6
	if now >= (session.sizzle_at or 0) then
		session.sizzle_at = now + LAVA_SIZZLE_INTERVAL
		str_audio.sfx.play("sizzle", {player = player})
	end
end
str_audio.sfx.register("vehicle_tire_impact", {
	sound = "str_machine_vehicle_tire_impact", category = "vehicle", max_hear_distance = 32,
})

-- Dig sound per stratum (or "dirt"/"surface" for the top rows)
local DUG_SOUND = {
	dirt = "soil", surface = "soil", topsoil = "soil",
	clay = "gravel", sandstone = "gravel",
	limestone = "rock", shale = "rock", slate = "rock", marble = "rock", schist = "rock",
	gneiss = "hardrock", basalt = "hardrock", granite = "hardrock", quartzite = "hardrock",
	eclogite = "hardrock", peridotite = "hardrock", core = "hardrock",
	formation = "hardrock",
}
for _, kind in ipairs({"soil", "gravel", "rock", "hardrock", "wood"}) do
	str_audio.sfx.register("dug_" .. kind, {
		sound = "str_machine_dug_" .. kind, max_hear_distance = 32, pitch = kind == "gravel" and 0.5 or nil,
	})
end

local function dug_sound(node_name)
	local def = core.registered_nodes[node_name]
	if def and def.str_dug_sound then
		return def.str_dug_sound
	end
	local host = node_name:match("_in_(%a+)$")
	if not host then
		host = ((def and def.str_base) or node_name):match("^str_nodes:(%a+)")
	end
	return DUG_SOUND[host or ""]
end

-- Out of fuel: engine stays on idle, no burner
local function engine_sound(session, player, control)
	if session.muted then
		return
	end
	local sfx = str_audio.sfx
	local climbing = session.thrusting
	local has_fuel = not fuel.is_empty(player)
	local engine = "engine_idle"
	if has_fuel then
		if session.dig then
			engine = "engine_rev"
		elseif climbing or control.left ~= control.right or (session.surface and control.up ~= control.down) then
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
	if session.dig and session.dig.cut then
		sfx.start_loop(player, "cut", "saw_loop")
	else
		sfx.stop_loop(player, "cut")
	end
end

local function stop_engine_sound(player)
	str_audio.sfx.stop_loop(player, "engine")
	str_audio.sfx.stop_loop(player, "burner")
	str_audio.sfx.stop_loop(player, "cut")
end

local CAM_DISTANCE = 12
local CAM_START_DISTANCE = 4
-- The camera starts CAM_START_DISTANCE away and backs off to CAM_DISTANCE at this speed (nodes/s)
local CAM_PULLBACK_SPEED = 2
-- Holding zoom pulls the camera in to CAM_ZOOM_DISTANCE at this speed (nodes/s)
local CAM_ZOOM_DISTANCE = 3
local CAM_ZOOM_SPEED = 8
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
local MAX_FALL_SPEED = str_utils.constants.max_fall_speed
-- Sneak hover: vertical speed (nodes/s) with up/down held, and its fuel burn multiplier
local HOVER_SPEED = 2
local HOVER_FUEL_MULT = 1.25
local LIQUID = str_utils.constants.liquid
-- Easing onto the dig row/column
local ALIGN_SPEED = 3
local ALIGN_RATE = 10
local ALIGN_TOLERANCE = 0.03
-- Nodes per second squared; per session so it can differ per planet later
local DEFAULT_GRAVITY = 15
-- Seconds to dig a node unless it defines str_hardness
local DEFAULT_HARDNESS = 1
-- How far (in nodes) the machine bites into the node by the time the dig finishes
local PUSH_DEPTH = 0.25
-- Look north (+z), so +x (east) is on the right of the screen; level in the slice, down at the machine in surface mode
local LOOK_YAW = 0
local LOOK_RANGE = math.rad(30)
local LOOK_MARGIN = math.rad(0.5)
local SURFACE_Y = str_utils.constants.surface_y
local SLICE_Z = str_utils.constants.slice_z
-- Surface mode: the machine drives the rows behind the slice, up to the end of the terrain
local SURFACE_MIN_Z = SLICE_Z + 1
local SURFACE_MAX_Z = SLICE_Z + str_utils.constants.back_depth
local WORLD_HALF_WIDTH = str_utils.constants.world_half_width
-- Seconds Space is held in the slice, above ground, before the machine moves behind it
local SURFACE_HOLD = 0.4
-- Glide speed (nodes/s) between the slice and the row behind it, and how long a blocked glide may take
local SHIFT_SPEED = 4
local SHIFT_TIMEOUT = 1
-- Surface camera: height over distance behind the machine, and how fast that ratio eases on a mode change (per s)
local SURFACE_CAM_DISTANCE = 9
local SURFACE_CAM_RATIO = 6 / SURFACE_CAM_DISTANCE
local CAM_RATIO_SPEED = 1.5
-- Climbs one-node steps on its own while driving the surface
local SURFACE_STEP_HEIGHT = 1.1
-- In front of the shop; the machine rests on the ground node, so its centre is one node above it
local START_POS = vector.new(str_utils.constants.shop_x, SURFACE_Y + 1, SLICE_Z)
-- Machine glow in full daylight; it scales down with the world light level
local MAX_GLOW = 10

str_hud.register_strip("str_machine:top_bar", {height = 44, color = "#00000080"})

local DEPTH_HUD = "str_machine:depth"
local DEPTH_INTERVAL = 0.2
str_hud.register_text(DEPTH_HUD, {
	position = {x = 0.5, y = 0}, offset = {x = -120, y = 22}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", mono = true,
})

local SPEED_HUD = "str_machine:vertical_speed"
str_hud.register_text(SPEED_HUD, {
	position = {x = 0.5, y = 0}, offset = {x = 120, y = 22}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", mono = true,
})

local function update_speed(player, vel_y)
	-- Rounded to a tenth; "+0.0" is shown as "0.0" so it never flickers between signs
	local speed = math.floor(vel_y * 10 + 0.5) / 10
	str_hud.set_text(player, SPEED_HUD, string.format(speed > 0 and "V: +%.1f m/s" or "V: %.1f m/s", speed + 0))
end

local PAD_HUD = "str_machine:pad"
str_hud.register_text(PAD_HUD, {
	position = {x = 0.5, y = 0.5}, offset = {x = 0, y = -90}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", background = {},
})

local depth_listeners = {}
local last_depth = {}
local MAX_DEPTH_KEY = "str_machine:max_depth"

-- Deepest whole-metre depth the machine has reached; 0 for saves from before it was tracked
function str_machine.get_max_depth(player)
	return math.max(player:get_meta():get_int(MAX_DEPTH_KEY), 0)
end

-- fn(player, depth, old_depth) on a whole-metre depth change; depth is below the start (negative above)
function str_machine.register_on_depth_change(fn)
	depth_listeners[#depth_listeners + 1] = fn
end

local function update_depth(player, pos)
	local y = math.floor(pos.y + 0.5) - START_POS.y
	local label = y > 0 and "Altitude" or "Depth"
	local text = string.format("%s: %dm  |  X: %d", label, math.abs(y), math.floor(pos.x + 0.5))
	local behind = math.floor(pos.z + 0.5) - SLICE_Z
	if behind > 0 then
		text = text .. string.format("  |  Z: %d", behind)
	end
	str_hud.set_text(player, DEPTH_HUD, text)
	local name = player:get_player_name()
	local depth, old = -y, last_depth[name]
	if depth ~= old then
		last_depth[name] = depth
		if depth > str_machine.get_max_depth(player) then
			player:get_meta():set_int(MAX_DEPTH_KEY, depth)
		end
		local playing = str_audio.music.current(player)
		if depth >= 10 then
			if playing ~= "underground" then
				str_audio.music.play(player, "underground", function()
					return (last_depth[name] or 0) >= 10
				end)
			end
		elseif depth > 1 and playing == "foot" then
			str_audio.music.stop(player)
		end
		for _, fn in ipairs(depth_listeners) do
			fn(player, depth, old)
		end
	end
end

local TOOLS_MAIL_DEPTH = 1000
local function check_tools_mail(player)
	if str_machine.get_max_depth(player) >= TOOLS_MAIL_DEPTH then
		str_mail.send_story(player:get_player_name(), "jim_tools")
	end
end
str_machine.register_on_depth_change(check_tools_mail)
core.register_on_joinplayer(check_tools_mail)

local dig_listeners = {}

-- fn(player, pos, node_name, method) for every node destroyed for the player, even if the hold is full
function str_machine.register_on_dig(fn)
	dig_listeners[#dig_listeners + 1] = fn
end

function str_machine.notify_dig(player, pos, node_name, method)
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
-- Nudge into a platform slab (1/16 thick) so the engine lets the box pass through it
local PASS_NUDGE = 0.1

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
-- Under pi per server step, or the client's shortest-path interpolation spins the cones backwards
local DRILL_SPIN_SPEED = 25
local DRILL_SPIN_ACCEL = 40
local DRILL_CONES = {"drill_l_cone", "drill_r_cone"}
-- Nozzle offsets from the machine origin at yaw 0 (the tail is +x)
local NOZZLES = {vector.new(0.22, -0.31, 0.31), vector.new(0.22, -0.31, -0.31)}
local EXHAUST_TEXTURE = {
	name = "str_machine_exhaust.png",
	blend = "alpha",
	scale_tween = {1, 2.2},
}

local WHEELS = {"wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"}
-- Position changes bigger than this in one step are teleports, not rolling
local MAX_ROLL_STEP = 1

local sessions = {}

-- Silences the engine and burner until unmuted (e.g. under a fullscreen screen); the next step restarts them
function str_machine.set_muted(player, muted)
	local session = sessions[player:get_player_name()]
	if session then
		session.muted = muted or nil
	end
	if muted then
		stop_engine_sound(player)
	end
end

local colors = str_machine.colors
local color_listeners = {}

-- The player's chosen colors plus the equipped thruster kind and drill level (the defaults without a player)
function str_machine.get_colors(player)
	local chosen = colors.get(player)
	if player then
		chosen.thruster_kind = stats.get_level(player, "thrusters").kind
		chosen.drill = stats.get_level(player, "drill").name
		chosen.hull = stats.get_level(player, "hull").name
	end
	return chosen
end

function str_machine.model_textures(player)
	return colors.textures(str_machine.get_colors(player))
end

-- fn(player, textures) runs after the model look changes (colors or parts), so display models can follow
function str_machine.register_on_colors_changed(fn)
	color_listeners[#color_listeners + 1] = fn
end

local function refresh_model(player)
	local textures = str_machine.model_textures(player)
	local session = sessions[player:get_player_name()]
	if session and session.obj:is_valid() then
		session.obj:set_properties({textures = textures})
		session.drills_scale = colors.apply_bit(session.obj, stats.get_level(player, "drill").name)
	end
	for _, fn in ipairs(color_listeners) do
		fn(player, textures)
	end
end

stats.register_on_change(refresh_model)
core.register_on_joinplayer(refresh_model)

-- key is a colors.defaults key, hex is "#rrggbb"; updates the machine now and the display models via listeners
function str_machine.set_color(player, key, hex)
	if not colors.set(player, key, hex) then
		return false
	end
	refresh_model(player)
	return true
end

core.register_entity("str_machine:machine", {
	initial_properties = {
		visual = "mesh",
		mesh = "digger1.glb",
		visual_size = {x = 10, y = 10, z = 10},
		textures = str_machine.model_textures(),
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

core.register_entity("str_machine:rig", {
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

local function wrap_angle(a)
	a = a % (2 * math.pi)
	return a > math.pi and a - 2 * math.pi or a
end

-- Turns the shortest way, in (-pi, pi]; a half turn between 0 and pi swings the way it always did
local function turn(yaw, target, step)
	target = wrap_angle(target)
	local diff = (target - yaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) > math.pi - 1e-6 then
		diff = target - yaw
	end
	return wrap_angle(yaw + math.max(-step, math.min(step, diff)))
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

-- "free": nothing solid in that direction, "dig": diggable node touching, "pass": platform to drop through or rise through,
-- "blocked": anything else (undiggable, above the drill tier, unloaded, or sideways without floor)
local function classify(pos, entry, on_ground, can_dig_up, drill_tier)
	local dir = entry.dir
	if dir.y > 0 then
		local cell = vector.round(pos)
		local cell_def = node_def(cell)
		if cell_def and cell_def.str_platform
				and cell.y + 0.4375 - (pos.y + BOX_TOP) <= TOUCH_DISTANCE then
			local above = node_def(vector.offset(cell, 0, 1, 0))
			-- The box ends up standing in the cell above, so that must be free
			return (above and (not above.walkable or above.str_platform)) and "pass" or "blocked"
		end
	end
	local reach = dir.y < 0 and -BOX_BOTTOM or (dir.y > 0 and BOX_TOP or HALF_WIDTH)
	local target = vector.round(vector.offset(pos,
		dir.x * (reach + TOUCH_DISTANCE), dir.y * (reach + TOUCH_DISTANCE), 0))
	local def = node_def(target)
	if not def then
		return "blocked"
	elseif not def.walkable then
		return "free"
	elseif def.str_platform then
		return dir.y < 0 and "pass" or "blocked"
	elseif def.diggable == false or (dir.y == 0 and not on_ground)
			or (dir.y > 0 and not can_dig_up) or (def.str_tier or 0) > drill_tier then
		return "blocked"
	end
	return "dig", target
end

local function start_dig(session, pick, anchor, cut)
	session.dig = {entry = pick.entry, target = pick.target, time = 0, anchor = anchor, cut = cut}
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

local DUST_COUNT = 6

local function spawn_dust(pos, node_name)
	local palette = str_nodes.dust_colors(node_name)
	for _ = 1, DUST_COUNT do
		core.add_particle({
			pos = vector.offset(pos, (math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6),
			velocity = vector.new((math.random() - 0.5) * 1.2, math.random() * 0.6, (math.random() - 0.5) * 1.2),
			acceleration = vector.new(0, 0.2, 0),
			expirationtime = 0.4 + math.random() * 0.3,
			size = 4 + math.random() * 2,
			texture = {name = "str_machine_puff.png^[multiply:" .. palette[math.random(#palette)], blend = "alpha",
				alpha_tween = {1, 0}, scale_tween = {0.6, 1.6}},
		})
	end
end

local LANDING_DUST_MIN, LANDING_DUST_MAX = 6, 20

-- t is the impact scale (0..1)
local function spawn_landing_dust(pos, t)
	local ground = vector.round(vector.new(pos.x, pos.y + BOX_BOTTOM - TOUCH_DISTANCE, pos.z))
	local palette = str_nodes.dust_colors(core.get_node(ground).name)
	local count = math.floor(LANDING_DUST_MIN + (LANDING_DUST_MAX - LANDING_DUST_MIN) * t + 0.5)
	local speed = 1.5 + 2.5 * t
	for _ = 1, count do
		local angle = math.random() * math.pi
		local dx, dy = math.cos(angle), math.sin(angle)
		core.add_particle({
			pos = vector.new(pos.x + dx * HALF_WIDTH, pos.y + BOX_BOTTOM + 0.05, pos.z + (math.random() - 0.5) * 0.4),
			velocity = vector.new(dx * speed, dy * speed * 0.5, (math.random() - 0.5) * 0.4),
			acceleration = vector.new(-dx * speed * 1.2, -0.5, 0),
			expirationtime = 0.4 + math.random() * 0.3,
			size = (3 + math.random() * 2) * (0.8 + 0.4 * t),
			texture = {name = "str_machine_puff.png^[multiply:" .. palette[math.random(#palette)], blend = "alpha",
				alpha_tween = {1, 0}, scale_tween = {0.6, 1.6}},
		})
	end
end

-- Nodes with str_material and str_yield add that much of the item to the hold; what does not fit stays as a pile.
-- A blasted node is destroyed: no yield and no dig sound
local function take_node(pos, player, blasted)
	local def = node_def(pos)
	local item = def and def.str_material
	local node_name = core.get_node(pos).name
	core.remove_node(pos)
	str_nodes.refresh_shapes(pos)
	spawn_dust(pos, node_name)
	local kind = not blasted and dug_sound(node_name)
	if kind then
		str_audio.sfx.play("dug_" .. kind, {player = player})
	end
	str_machine.notify_dig(player, pos, node_name, blasted and "blast" or "drill")
	if item and not blasted then
		local yield = def.str_yield or 1
		local added = cargo.add(player, item, yield)
		cargo.announce(player, item, added)
		str_piles.drop(pos, item, yield - added)
		if added < yield or cargo.volume(player) >= stats.get(player).cargo_capacity - 1e-6 then
			str_utils.show_popup(player:get_player_name(), "CARGO FULL!", 2, false,
				{color = 0xFF4500, size = 1.25})
		end
	end
	if def and def.str_on_dug and not blasted then
		def.str_on_dug(player)
	end
	return true
end

-- With the hull upgrade, a liquid source the machine is in goes into the hold whole, or stays if it does not fit
local function collect_liquid(session, player, cell, def)
	if def.liquidtype ~= "source" or not def.str_material
			or not str_machine.hull_slots.has(player, "str_machine:hull_liquid_collection") then
		return
	end
	local yield = def.str_yield or 1
	if cargo.volume(player) + yield * str_materials.get(def.str_material).volume > stats.get(player).cargo_capacity + 1e-6 then
		if not session.liquid_full_cell or not vector.equals(cell, session.liquid_full_cell) then
			session.liquid_full_cell = cell
			str_utils.show_popup(player:get_player_name(), "CARGO FULL!", 2, false, {color = 0xFF4500, size = 1.25})
		end
		return
	end
	session.liquid_full_cell = nil
	core.remove_node(cell)
	cargo.announce(player, def.str_material, cargo.add(player, def.str_material, yield))
	local dps = def.damage_per_second or 0
	if dps > 0 then
		local seconds = LIQUID.collect_exposure
		local share = str_machine.heat.absorb(player, seconds)
		if share > 0 then
			hull.damage(player, seconds * dps * share)
			sizzle(session, player)
		end
	end
end

-- Destroys a solid, diggable node up to max_tier regardless of the drill; returns whether it did
function str_machine.destroy_node(player, pos, max_tier)
	local def = node_def(pos)
	if not def or not def.walkable or def.diggable == false or (def.str_tier or 0) > max_tier then
		return false
	end
	return take_node(pos, player, true)
end

-- Whether the tree at pos cannot be cut because its yield does not fit; says so once per trunk
local function cut_blocked(session, player, pos)
	local volume = 0
	for item, range in pairs((node_def(pos) or {}).str_fell_yield or {}) do
		volume = volume + range[2] * str_materials.get(item).volume
	end
	if cargo.volume(player) + volume <= stats.get(player).cargo_capacity + 1e-6 then
		session.cut_full_pos = nil
		return false
	end
	if not session.cut_full_pos or not vector.equals(pos, session.cut_full_pos) then
		session.cut_full_pos = pos
		str_utils.show_popup(player:get_player_name(), "CARGO FULL!", 2, false, {color = 0xFF4500, size = 1.25})
	end
	return true
end

-- Cuts down the tree whose base node is at pos, leaving its stump, and puts its yield in the hold
local function fell_tree(pos, player)
	local def = node_def(pos)
	local kind = dug_sound(core.get_node(pos).name)
	if not str_decor.fell(pos) then
		return false
	end
	if kind then
		str_audio.sfx.play("dug_" .. kind, {player = player})
	end
	for item, range in pairs(def.str_fell_yield or {}) do
		cargo.announce(player, item, cargo.add(player, item, math.random(range[1], range[2])))
	end
	return true
end

-- Downward speed given right after digging the node below
local DIG_DOWN_SPEED = 1.5

local function dig_step(session, player, pick, dtime)
	local dig = session.dig
	dig.time = dig.time + dtime
	local hardness = (node_def(pick.target).str_hardness or DEFAULT_HARDNESS)
		/ stats.get(player).dig_speed
	if dig.time >= hardness then
		local entry = dig.entry
		if dig.cut then
			end_dig(session, not cut_blocked(session, player, pick.target) and fell_tree(pick.target, player))
			return
		end
		end_dig(session, take_node(pick.target, player))
		if entry.dir.y < 0 then
			session.obj:set_velocity(vector.new(0, -DIG_DOWN_SPEED, 0))
		end
	else
		local push = PUSH_DEPTH * dig.time / hardness
		session.obj:move_to(vector.add(dig.anchor, vector.multiply(dig.entry.dir, push)), true)
	end
end

local FUEL = str_utils.constants.fuel

local function burn_fuel(player, multiplier, dtime)
	fuel.remove(player, FUEL.burn_per_second * multiplier * stats.get(player).fuel_use * dtime)
end

local function control_step(session, player, pos, control, dtime)
	local dig = session.dig
	local my_stats = stats.get(player)
	local class_pos = dig and dig.anchor or pos
	local on_ground = grounded(class_pos)
	session.thrusting = control.up and not control.down
	local free, digs, pass = false, {}, nil
	for _, entry in ipairs(held_entries(control)) do
		local kind, target = classify(class_pos, entry, on_ground, my_stats.can_dig_up, my_stats.drill_tier)
		if kind == "free" then
			free = true
		elseif kind == "pass" then
			pass = entry.dir.y
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
		start_dig(session, pick, vector.new(align_x or pos.x, pos.y, pos.z))
		return
	end
	if pass and not free and not pick then
		align_x = math.floor(pos.x + 0.5)
		if math.abs(pos.x - align_x) <= ALIGN_TOLERANCE then
			session.obj:set_pos(vector.new(align_x, pos.y + pass * PASS_NUDGE, pos.z))
			return
		end
	end

	local vel = session.obj:get_velocity()
	local speed_mult = fuel.is_empty(player) and FUEL.empty_speed_mult or 1
	local top_thrust = my_stats.thrust * speed_mult
	if session.liquid then
		top_thrust = my_stats.thrust * math.min(speed_mult, LIQUID.climb_speed_mult)
		speed_mult = speed_mult * LIQUID.speed_mult
	end
	local target_vx = ((control.right and 1 or 0) - (control.left and 1 or 0)) * my_stats.move_speed * speed_mult
	if align_x then
		target_vx = math.max(-ALIGN_SPEED, math.min(ALIGN_SPEED, (align_x - pos.x) * ALIGN_RATE))
	end
	vel.x = approach(vel.x, target_vx, ACCEL * dtime)
	local accel_y = -session.gravity
	local hovering = control.sneak and not fuel.is_empty(player) and (control.up or not on_ground)
	local climbing = not hovering and control.up and not control.down
	session.thrusting = hovering or climbing
	if hovering then
		burn_fuel(player, HOVER_FUEL_MULT, dtime)
	elseif climbing then
		burn_fuel(player, FUEL.climb_mult, dtime)
	elseif control.left ~= control.right then
		burn_fuel(player, 1, dtime)
	end
	local thrust_accel = THRUST_ACCEL / (1 + RATED_DRAG * cargo.weight(player) / my_stats.thrust_rating)
	if hovering then
		local target_vy = ((control.up and 1 or 0) - (control.down and 1 or 0)) * HOVER_SPEED
		-- Thrust pushes up, gravity alone pulls down; either stops exactly at the target speed
		if vel.y <= target_vy then
			accel_y = math.min(thrust_accel - session.gravity, (target_vy - vel.y) / dtime)
		else
			accel_y = math.max(-session.gravity, (target_vy - vel.y) / dtime)
		end
	elseif climbing then
		accel_y = thrust_accel - session.gravity
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

-- Whether the machine's box would fit at its x and y in row z
local function box_clear(pos, z)
	for _, x in ipairs({pos.x - HALF_WIDTH + 0.01, pos.x + HALF_WIDTH - 0.01}) do
		for _, y in ipairs({pos.y + BOX_BOTTOM + 0.01, pos.y + BOX_TOP - 0.01}) do
			local def = node_def(vector.round(vector.new(x, y, z)))
			if not def or def.walkable then
				return false
			end
		end
	end
	return true
end

local function set_step_height(session, height)
	if session.stepheight ~= height then
		session.stepheight = height
		session.obj:set_properties({stepheight = height})
	end
end

local function set_surface(session, surface)
	session.surface = surface or nil
	session.obj:set_properties({step_up_mode = surface and "floaty" or "legacy"})
	set_step_height(session, 0)
end

-- Glides the machine to row z, controls ignored; surface mode follows the row it ends in
local function start_shift(session, pos, z)
	if session.surface then
		set_surface(session, false)
	end
	session.shift = {from_z = pos.z, to_z = z, t = 0}
	session.thrusting = false
end

local function shift_step(session, player, pos, dtime)
	local shift = session.shift
	shift.t = shift.t + dtime
	local dz = shift.to_z - pos.z
	local blocked = shift.t > SHIFT_TIMEOUT
	if math.abs(dz) > 1e-3 and not blocked then
		local speed = math.min(SHIFT_SPEED, math.abs(dz) / dtime)
		session.obj:set_velocity(vector.new(0, 0, dz > 0 and speed or -speed))
		session.obj:set_acceleration(vector.zero())
		return
	end
	local z = blocked and shift.from_z or shift.to_z
	session.obj:set_pos(vector.new(pos.x, pos.y, z))
	session.obj:set_velocity(vector.zero())
	session.shift = nil
	local surface = z > SLICE_Z + 0.5
	if surface then
		set_surface(session, true)
	else
		session.target_yaw = math.cos(session.yaw) >= 0 and 0 or math.pi
	end
	if not blocked then
		str_utils.show_popup(player:get_player_name(), surface and "Surface mode" or "Digger mode", 1.5, false)
	end
end

-- Holding Space above ground in the slice, with room behind, moves the machine onto the surface behind it
local function check_surface_entry(session, pos, control, dtime)
	if not control.jump then
		session.jump_time, session.jump_lock = 0, nil
		return false
	end
	session.jump_time = (session.jump_time or 0) + dtime
	if session.jump_lock or session.dig or session.jump_time < SURFACE_HOLD
			or math.floor(pos.y + 0.5) <= SURFACE_Y or not box_clear(pos, SURFACE_MIN_Z) then
		return false
	end
	session.jump_lock = true
	start_shift(session, pos, SURFACE_MIN_Z)
	return true
end

-- Velocity component v, cut so one step does not carry p past lo or hi
local function bound(v, p, lo, hi, dtime)
	return math.max((lo - p) / dtime, math.min((hi - p) / dtime, v))
end

-- Slip speed (fraction of the push) and centre offset (nodes) below which a trunk hit counts as head-on
local HEAD_ON_SLIP = 0.5
local HEAD_ON_OFFSET = 0.02

-- The machine and tree trunks (str_trunk_radius) collide as upright cylinders, so the machine slides round trunks
local function slide_trunks(pos, vel, dtime)
	local reach = HALF_WIDTH + 0.5 + math.sqrt(vel.x ^ 2 + vel.z ^ 2) * dtime
	local y0 = math.floor(pos.y + BOX_BOTTOM + 0.51)
	local y1 = math.floor(pos.y + BOX_TOP + 0.49)
	for x = math.floor(pos.x - reach + 0.5), math.floor(pos.x + reach + 0.5) do
		for z = math.floor(pos.z - reach + 0.5), math.floor(pos.z + reach + 0.5) do
			for y = y0, y1 do
				local def = node_def(vector.new(x, y, z))
				local r = def and def.str_trunk_radius
				if r then
					local ox, oz = pos.x - x, pos.z - z
					local d = math.sqrt(ox * ox + oz * oz)
					if d > 1e-6 then
						local nx, nz = ox / d, oz / d
						local vn = vel.x * nx + vel.z * nz
						local allowed = -math.max(d - HALF_WIDTH - r, 0) / dtime
						if vn < allowed then
							local push = allowed - vn
							vel.x, vel.z = vel.x + push * nx, vel.z + push * nz
							local slip = push * HEAD_ON_SLIP
							if math.abs(nx) >= math.abs(nz) and math.abs(oz) < HEAD_ON_OFFSET then
								vel.z = vel.z + (pos.z > SURFACE_MAX_Z - 0.5 and -slip or slip)
							elseif math.abs(nz) > math.abs(nx) and math.abs(ox) < HEAD_ON_OFFSET then
								vel.x = vel.x + (ox < 0 and -slip or slip)
							end
						end
					end
					break
				end
			end
		end
	end
end

-- Trunks (str_trunk_radius) as square boxes: each axis stops at the face, as against a node
local function block_trunks(pos, vel, dtime)
	local reach = HALF_WIDTH + 0.5 + math.sqrt(vel.x ^ 2 + vel.z ^ 2) * dtime
	local y0 = math.floor(pos.y + BOX_BOTTOM + 0.51)
	local y1 = math.floor(pos.y + BOX_TOP + 0.49)
	local trunks = {}
	for x = math.floor(pos.x - reach + 0.5), math.floor(pos.x + reach + 0.5) do
		for z = math.floor(pos.z - reach + 0.5), math.floor(pos.z + reach + 0.5) do
			for y = y0, y1 do
				local def = node_def(vector.new(x, y, z))
				if def and def.str_trunk_radius then
					trunks[#trunks + 1] = {x = x, z = z, r = def.str_trunk_radius + HALF_WIDTH}
					break
				end
			end
		end
	end
	-- Already inside a trunk (a step overshot its face): only the shallower axis is blocked
	for _, t in ipairs(trunks) do
		local gx, gz = math.abs(t.x - pos.x) - t.r, math.abs(t.z - pos.z) - t.r
		if gx < 0 and gz < 0 then
			t.inside = true
			if gx >= gz then
				vel.x = t.x > pos.x and math.min(vel.x, 0) or math.max(vel.x, 0)
			else
				vel.z = t.z > pos.z and math.min(vel.z, 0) or math.max(vel.z, 0)
			end
		end
	end
	local function clamp_x()
		local next_z = pos.z + vel.z * dtime
		for _, t in ipairs(trunks) do
			if not t.inside and math.abs(next_z - t.z) < t.r - 1e-3 then
				local o = t.x - pos.x
				local gap = math.max(math.abs(o) - t.r, 0) / dtime
				vel.x = o > 0 and math.min(vel.x, gap) or math.max(vel.x, -gap)
			end
		end
	end
	local function clamp_z()
		local next_x = pos.x + vel.x * dtime
		for _, t in ipairs(trunks) do
			if not t.inside and math.abs(next_x - t.x) < t.r - 1e-3 then
				local o = t.z - pos.z
				local gap = math.max(math.abs(o) - t.r, 0) / dtime
				vel.z = o > 0 and math.min(vel.z, gap) or math.max(vel.z, -gap)
			end
		end
	end
	-- The faster axis stops at the face first, so the slower sideways glide is not cancelled by its overshoot
	if math.abs(vel.z) > math.abs(vel.x) then
		clamp_z()
		clamp_x()
	else
		clamp_x()
		clamp_z()
	end
end

-- The tree base node touching the machine's face in direction (dx, dz), if its trunk overlaps that face
local function trunk_ahead(pos, dx, dz)
	local y0 = math.floor(pos.y + BOX_BOTTOM + 0.51)
	local y1 = math.floor(pos.y + BOX_TOP + 0.49)
	local fx = math.floor(pos.x + dx * (HALF_WIDTH + 0.5) + 0.5)
	local fz = math.floor(pos.z + dz * (HALF_WIDTH + 0.5) + 0.5)
	for side = -1, 1 do
		for y = y0, y1 do
			local p = vector.new(fx + side * math.abs(dz), y, fz + side * math.abs(dx))
			local def = node_def(p)
			local r = def and def.str_tree == "base" and def.str_trunk_radius
			if r then
				local ahead = dx * (p.x - pos.x) + dz * (p.z - pos.z)
				local lateral = math.abs(dz) * (p.x - pos.x) + math.abs(dx) * (p.z - pos.z)
				if ahead - HALF_WIDTH - r <= TOUCH_DISTANCE and math.abs(lateral) < HALF_WIDTH + r - 1e-3 then
					return p
				end
			end
		end
	end
end

-- A straight push cuts a trunk centred within this of the machine (nodes) and slides round one further off
local CUT_RANGE = 0.25

local function cut_dir(control)
	local ix = (control.right and 1 or 0) - (control.left and 1 or 0)
	local iz = (control.up and 1 or 0) - (control.down and 1 or 0)
	if (ix == 0) ~= (iz == 0) then
		return vector.new(ix, 0, iz)
	end
end

-- WASD drives on the ground plane, Space climbs, Sneak hovers; S in the row behind the slice drives back into it
local function surface_step(session, player, pos, control, dtime)
	local my_stats = stats.get(player)
	local dig = session.dig
	if dig then
		local dir = cut_dir(control)
		local def = node_def(dig.target)
		if dir and vector.equals(dir, dig.entry.dir) and def and def.str_tree == "base"
				and not fuel.is_empty(player) and grounded(dig.anchor) then
			burn_fuel(player, FUEL.dig_mult, dtime)
			dig_step(session, player, {entry = dig.entry, target = dig.target}, dtime)
			return
		end
		end_dig(session, false)
	end
	if control.down and not control.up and pos.z <= SURFACE_MIN_Z + 0.05 and box_clear(pos, SLICE_Z) then
		session.jump_lock = control.jump or nil
		session.down_lock = true
		start_shift(session, pos, SLICE_Z)
		return
	end
	-- Space still held from entering only thrusts once let go
	if not control.jump then
		session.jump_lock = nil
	end
	local jump = control.jump and not session.jump_lock
	local on_ground = grounded(pos)
	-- Steps up only from the ground, so a hovering machine cannot climb walls
	set_step_height(session, on_ground and SURFACE_STEP_HEIGHT or 0)
	local empty = fuel.is_empty(player)
	local vel = session.obj:get_velocity()
	local speed_mult = empty and FUEL.empty_speed_mult or 1
	local top_thrust = my_stats.thrust * speed_mult
	if session.liquid then
		top_thrust = my_stats.thrust * math.min(speed_mult, LIQUID.climb_speed_mult)
		speed_mult = speed_mult * LIQUID.speed_mult
	end
	local ix = (control.right and 1 or 0) - (control.left and 1 or 0)
	local iz = (control.up and 1 or 0) - (control.down and 1 or 0)
	local speed = my_stats.move_speed * speed_mult / ((ix ~= 0 and iz ~= 0) and math.sqrt(2) or 1)
	vel.x = approach(vel.x, ix * speed, ACCEL * dtime)
	vel.z = approach(vel.z, iz * speed, ACCEL * dtime)
	local dir = my_stats.can_cut_trees and cut_dir(control)
	local target = dir and trunk_ahead(pos, dir.x, dir.z)
	local off = target and (dir.x ~= 0 and target.z - pos.z or target.x - pos.x)
	if off and math.abs(off) > CUT_RANGE then
		local side = off > 0 and -speed or speed
		if dir.x ~= 0 then
			vel.z = approach(vel.z, side, ACCEL * dtime)
		else
			vel.x = approach(vel.x, side, ACCEL * dtime)
		end
	elseif off and on_ground and not empty and not jump then
		if math.abs(off) <= ALIGN_TOLERANCE and not cut_blocked(session, player, target) then
			local anchor = dir.x ~= 0 and vector.new(pos.x, pos.y, target.z) or vector.new(target.x, pos.y, pos.z)
			start_dig(session, {entry = {dir = dir}, target = target}, anchor, true)
			return
		end
		local glide = math.max(-ALIGN_SPEED, math.min(ALIGN_SPEED, off * ALIGN_RATE))
		if dir.x ~= 0 then
			vel.z = approach(vel.z, glide, ACCEL * dtime)
		else
			vel.x = approach(vel.x, glide, ACCEL * dtime)
		end
	end
	if my_stats.can_cut_trees then
		block_trunks(pos, vel, dtime)
	else
		slide_trunks(pos, vel, dtime)
	end
	vel.x = bound(vel.x, pos.x, -WORLD_HALF_WIDTH, WORLD_HALF_WIDTH, dtime)
	vel.z = bound(vel.z, pos.z, SURFACE_MIN_Z, SURFACE_MAX_Z, dtime)
	local accel_y = -session.gravity
	local hovering = control.sneak and not empty and (jump or not on_ground)
	local climbing = not hovering and jump
	session.thrusting = hovering or climbing
	if hovering then
		burn_fuel(player, HOVER_FUEL_MULT, dtime)
	elseif climbing then
		burn_fuel(player, FUEL.climb_mult, dtime)
	elseif ix ~= 0 or iz ~= 0 then
		burn_fuel(player, 1, dtime)
	end
	local thrust_accel = THRUST_ACCEL / (1 + RATED_DRAG * cargo.weight(player) / my_stats.thrust_rating)
	if hovering then
		local target_vy = jump and HOVER_SPEED or 0
		if vel.y <= target_vy then
			accel_y = math.min(thrust_accel - session.gravity, (target_vy - vel.y) / dtime)
		else
			accel_y = math.max(-session.gravity, (target_vy - vel.y) / dtime)
		end
	elseif climbing then
		accel_y = thrust_accel - session.gravity
		if vel.y > top_thrust then
			vel.y = approach(vel.y, top_thrust, ACCEL * dtime)
			accel_y = 0
		else
			accel_y = math.min(accel_y, (top_thrust - vel.y) / dtime)
		end
	end
	vel.y = math.max(vel.y, -(session.liquid and LIQUID.max_fall_speed or MAX_FALL_SPEED))
	session.obj:set_velocity(vel)
	session.obj:set_acceleration(vector.new(0, accel_y, 0))
end

local EXHAUST_INTERVAL = 0.1
-- Per thruster kind (see thrusters.lua): particles per nozzle per burst (full tank, empty tank), downward speed, size and lifetime
-- as {minimum, random extra}; spread is the random sideways offset (nodes) of the spawn point; static = a single-frame texture
local EXHAUST_PROFILES = {
	propeller = {
		count = 2, empty_count = 0, speed = {3, 2}, size = {0.5, 0.3}, life = {0.12, 0.12}, spread = 0.1, static = true,
		texture = {name = "str_machine_wind.png", blend = "alpha"},
	},
	jet = {count = 3, empty_count = 1, speed = {2.5, 1.5}, size = {0.75, 0.45}, life = {0.4, 0.4}, spread = 0.03,
		texture = EXHAUST_TEXTURE},
	rocket = {
		count = 6, empty_count = 1, speed = {5, 3}, size = {1.2, 1}, life = {0.5, 0.5}, spread = 0.03,
		texture = {name = "str_machine_exhaust.png^[multiply:#ffa060", blend = "alpha", scale_tween = {1, 2.2}},
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
	local t = str_utils.impact_scale(fall)
	str_audio.sfx.play("vehicle_tire_impact", {
		pos = pos, gain = IMPACT_GAIN_MIN + (IMPACT_GAIN_MAX - IMPACT_GAIN_MIN) * t,
	})
	spawn_landing_dust(pos, t)
	hull.damage(player, str_utils.impact_damage(fall))
end
for _, name in ipairs({"engine_idle", "engine_mid", "engine_rev", "burner", "helicopter", "saw_loop"}) do
	str_audio.sfx.register(name, {sound = "str_machine_" .. name, category = "vehicle", gain = ENGINE_GAIN})
end

local function animate(session, player, control, dtime)
	local obj = session.obj

	engine_sound(session, player, control)
	impact(session, player, obj:get_pos(), obj:get_velocity().y)
	-- A hard landing can destroy the machine
	if session.destroyed then
		return
	end
	if session.thrusting and not session.liquid then
		spawn_exhaust(session, player, dtime)
	end

	local ix = (control.right and 1 or 0) - (control.left and 1 or 0)
	local iz = session.surface and (control.up and 1 or 0) - (control.down and 1 or 0) or 0
	if ix ~= 0 or iz ~= 0 then
		session.target_yaw = core.dir_to_yaw(vector.new(ix, 0, iz)) - math.pi / 2
	end
	session.yaw = turn(session.yaw, session.target_yaw, TURN_SPEED * dtime)
	obj:set_yaw(session.yaw)

	local pos = obj:get_pos()
	local dx = session.last_x and pos.x - session.last_x or 0
	local dz = session.last_z and pos.z - session.last_z or 0
	session.last_x, session.last_z = pos.x, pos.z
	local driving = (ix ~= 0 or iz ~= 0) and grounded(pos)
	if driving and math.abs(dx) + math.abs(dz) < MAX_ROLL_STEP then
		local forward = -(dx * math.cos(session.yaw) + dz * math.sin(session.yaw))
		session.wheel_angle = (session.wheel_angle + forward / WHEEL_RADIUS) % (2 * math.pi)
	end
	local drill_target = 0
	if session.surface or session.shift then
		drill_target = 0
	elseif control.down and not control.up then
		drill_target = math.pi / 2
	elseif control.up and not control.down and stats.get(player).can_dig_up then
		drill_target = -math.pi / 2
	end
	session.drill_pitch = approach(session.drill_pitch or 0, drill_target, DRILL_TURN_SPEED * dtime)
	obj:set_bone_override("drills_combined", {
		rotation = {vec = vector.new(0, 0, session.drill_pitch), absolute = true},
		scale = {vec = session.drills_scale or vector.new(1, 1, 1), absolute = true},
	})
	local spin_target = session.dig and DRILL_SPIN_SPEED or 0
	session.drill_spin_rate = approach(session.drill_spin_rate or 0, spin_target, DRILL_SPIN_ACCEL * dtime)
	if session.drill_spin_rate > 0 then
		session.drill_spin = ((session.drill_spin or 0) + session.drill_spin_rate * dtime) % (2 * math.pi)
		for _, bone in ipairs(DRILL_CONES) do
			obj:set_bone_override(bone, {
				rotation = {vec = vector.new(-session.drill_spin, 0, 0), interpolation = dtime, absolute = true},
			})
		end
	end
	for _, bone in ipairs(WHEELS) do
		obj:set_bone_override(bone, {rotation = {vec = vector.new(0, 0, session.wheel_angle), absolute = true}})
	end
end

-- Pitch that centres the view on the machine: level in the slice, down onto it in surface mode
local function look_pitch(session)
	return math.atan(session.cam_ratio)
end

local function reset_look(player, session)
	player:set_look_vertical(look_pitch(session))
	player:set_look_horizontal(LOOK_YAW)
end

-- Camera height follows its distance, so zooming keeps the angle
local function place_camera(session, distance)
	session.cam_offset = vector.new(0, session.cam_ratio * distance - session.eye_height, -distance)
end

-- Put the player in the camera rig and apply the vehicle view
local function board(player, session)
	player:set_attach(session.rig)
	player:set_camera({mode = "first"})
	player:set_properties({zoom_fov = 0})
	reset_look(player, session)
	session.look_pitch = look_pitch(session)
	player:hud_set_flags({wielditem = false, crosshair = false, hotbar = true})
	fuel.refresh(player)
	hull.refresh(player)
	str_machine.cargo.refresh(player)
	update_depth(player, session.obj:get_pos())
	player:set_sky({fog = {fog_distance = VIEW_DISTANCE, fog_start = FOG_START}})
end

local function start(player, pos)
	-- Behind the slice is surface mode; a position saved mid-glide goes to the nearer row
	local surface = pos.z > SLICE_Z + 0.5
	pos = vector.new(pos.x, pos.y, surface and math.max(pos.z, SURFACE_MIN_Z) or SLICE_Z)
	local obj = core.add_entity(pos, "str_machine:machine")
	if not obj then
		return
	end
	obj:set_properties({textures = str_machine.model_textures(player)})
	local session = {
		obj = obj, drills_scale = colors.apply_bit(obj, stats.get_level(player, "drill").name), gravity = DEFAULT_GRAVITY, dig = nil, depth_timer = 0, save_timer = 0,
		yaw = 0, target_yaw = 0, wheel_angle = 0, last_pos = pos,
		-- Lift the camera by the eye height so the view is centered on the machine
		eye_height = player:get_properties().eye_height, cam_ratio = surface and SURFACE_CAM_RATIO or 0,
	}
	place_camera(session, CAM_START_DISTANCE)
	-- The client camera ignores the attach offset, so attach to a separate rig
	local rig = core.add_entity(vector.add(pos, session.cam_offset), "str_machine:rig")
	if not rig then
		obj:remove()
		return
	end
	session.rig = rig
	set_surface(session, surface)
	sessions[player:get_player_name()] = session
	board(player, session)
end

local SAVED_POS_KEY = "str_machine:pos"
local DEATH_MAIL_KEY = "str_machine:death_mail_sent"
local SAVE_INTERVAL = 1

local function saved_pos(player)
	return core.string_to_pos(player:get_meta():get_string(SAVED_POS_KEY)) or START_POS
end

-- Where the machine starts when the player next boards (its last saved position)
str_machine.get_saved_pos = saved_pos

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
			if joined and not sessions[name] and str_mode.get(joined) == "vehicle" then
				start(joined, pos)
			end
		end)
end

-- Each look setter resends both angles (the other one stale), so only correct past a margin: resting on the edge sends nothing
local function clamp_look(player, pitch)
	local dyaw = (player:get_look_horizontal() - LOOK_YAW + math.pi) % (2 * math.pi) - math.pi
	local dpitch = player:get_look_vertical() - pitch
	if math.abs(dpitch) > LOOK_RANGE + LOOK_MARGIN then
		player:set_look_vertical(pitch + math.max(-LOOK_RANGE, math.min(LOOK_RANGE, dpitch)))
	end
	if math.abs(dyaw) > LOOK_RANGE + LOOK_MARGIN then
		player:set_look_horizontal(LOOK_YAW + math.max(-LOOK_RANGE, math.min(LOOK_RANGE, dyaw)))
	end
end

local NEIGHBOURS = {vector.new(1, 0, 0), vector.new(-1, 0, 0), vector.new(0, 0, 1), vector.new(0, 0, -1)}

-- Shows the prompt of the pad under the machine, else of an interactable node in its cell or behind it; a fresh Aux1
-- press uses it. In surface mode a building next to the machine counts as its pad instead. Returns true if that left
-- vehicle mode.
local function pad_step(session, player, pos, control)
	local target, use_pos
	if not session.dig and not session.shift then
		use_pos = vector.round(vector.new(pos.x, pos.y + BOX_BOTTOM - TOUCH_DISTANCE, pos.z))
		target = str_pads.get(use_pos)
		if session.surface then
			local cell = vector.round(pos)
			for _, dir in ipairs(NEIGHBOURS) do
				if target then
					break
				end
				use_pos = vector.add(cell, dir)
				target = str_pads.get(use_pos)
			end
		elseif not target then
			use_pos = vector.round(pos)
			target = str_interact.get(use_pos)
			if not target then
				use_pos = vector.round(vector.new(pos.x, pos.y, SLICE_Z + 1))
				target = str_interact.get(use_pos)
			end
		end
	end
	local label = target and ("[" .. str_utils.interact_key_name(player) .. "] " .. target.label) or ""
	if label ~= session.pad_label then
		session.pad_label = label
		str_hud.set_text(player, PAD_HUD, label)
	end
	local pressed = control.aux1 and not session.aux1_held
	session.aux1_held = control.aux1
	if target and pressed then
		target.on_use(player, use_pos)
		return str_mode.get(player) ~= "vehicle"
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

	local control = player:get_player_control()
	local surface_view = session.surface or (session.shift and session.shift.to_z > SLICE_Z + 0.5)
	session.cam_ratio = approach(session.cam_ratio, surface_view and SURFACE_CAM_RATIO or 0, CAM_RATIO_SPEED * dtime)
	local distance = -session.cam_offset.z
	if control.zoom then
		distance = approach(distance, CAM_ZOOM_DISTANCE, CAM_ZOOM_SPEED * dtime)
	else
		distance = approach(distance, surface_view and SURFACE_CAM_DISTANCE or CAM_DISTANCE, CAM_PULLBACK_SPEED * dtime)
	end
	place_camera(session, distance)
	local cam_target = vector.add(pos, session.cam_offset)
	local offset = vector.subtract(cam_target, rig_pos)
	session.rig:set_velocity(vector.multiply(offset, math.min(FOLLOW_SPEED, 1 / dtime)))

	-- The view tilts with the camera while it moves between the slice and surface views
	local pitch = look_pitch(session)
	if pitch ~= session.look_pitch then
		session.look_pitch = pitch
		reset_look(player, session)
	else
		clamp_look(player, pitch)
	end
	local light = stats.get(player)
	local ratio = str_environment.update(
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
	if session.frozen then
		session.obj:set_velocity(vector.zero())
		session.obj:set_acceleration(vector.zero())
		session.aux1_held = control.aux1
		if session.pad_label ~= "" then
			session.pad_label = ""
			str_hud.set_text(player, PAD_HUD, "")
		end
		return
	end
	if pad_step(session, player, pos, control) then
		return
	end
	-- Liquid in the node the machine occupies; its damage_per_second hurts the hull
	local def = node_def(vector.round(pos))
	session.liquid = def and def.liquidtype and def.liquidtype ~= "none" and def or nil
	local damage = session.liquid and session.liquid.damage_per_second or 0
	if str_machine.heat.step(player, damage > 0, dtime) then
		damage = 0
	end
	if damage > 0 then
		hull.damage(player, damage * dtime)
		if session.destroyed then
			return
		end
		sizzle(session, player)
	end
	local cell = vector.round(pos)
	if session.liquid then
		collect_liquid(session, player, cell, session.liquid)
		if session.destroyed then
			return
		end
	end
	if not session.pile_cell or not vector.equals(cell, session.pile_cell) then
		session.pile_cell = cell
		str_piles.collect(cell, function(item, count)
			local added = cargo.add(player, item, count)
			cargo.announce(player, item, added)
			return added
		end)
	end
	if not session.shift and not session.surface then
		-- S held from driving back into the slice does not dig until let go
		if session.down_lock and control.down then
			control.down = false
		else
			session.down_lock = nil
		end
		check_surface_entry(session, pos, control, dtime)
	end
	if session.shift then
		shift_step(session, player, pos, dtime)
		control = {}
	elseif session.surface then
		surface_step(session, player, pos, control, dtime)
	else
		control_step(session, player, pos, control, dtime)
	end
	animate(session, player, control, dtime)
end

local EXPLOSION_PARTICLES = 60
local DEATH_FORM = "str_machine:death"
local DEATH_W, DEATH_H = 8, 4
local DEATH_BUTTON_W, DEATH_BUTTON_H = 3, 0.9

local function show_death_screen(player)
	-- Close whatever else is open (e.g. the inventory) so the death screen is the only window
	core.close_formspec(player:get_player_name(), "")
	local fs = {
		str_gui.header(DEATH_W, DEATH_H, "Critical Hull Failure"),
		"allow_close[false]",
		("label[0.4,%g;%s]"):format(str_gui.CONTENT_Y + 0.4, "The machine has been destroyed."),
		("button[%g,%g;%g,%g;respawn;Respawn]"):format(
			(DEATH_W - DEATH_BUTTON_W) / 2, DEATH_H - DEATH_BUTTON_H - 0.4, DEATH_BUTTON_W, DEATH_BUTTON_H),
	}
	core.show_formspec(player:get_player_name(), DEATH_FORM, table.concat(fs))
end

-- The player driving this machine entity, or nil
function str_machine.owner(obj)
	for name, session in pairs(sessions) do
		if session.obj == obj then
			return core.get_player_by_name(name)
		end
	end
end

-- Position of the player's machine, or nil if they are not driving one
function str_machine.get_pos(player)
	local session = sessions[player:get_player_name()]
	return session and session.obj:get_pos()
end

-- A frozen machine holds still and ignores the controls, pads and interactables (used while travelling)
function str_machine.set_frozen(player, frozen)
	local session = sessions[player:get_player_name()]
	if session then
		session.frozen = frozen or nil
	end
end

-- Moves the machine and its camera rig to pos; the caller must have the map there ready
function str_machine.teleport(player, pos)
	local session = sessions[player:get_player_name()]
	if not session or session.destroyed then
		return
	end
	session.obj:set_pos(pos)
	session.obj:set_velocity(vector.zero())
	session.rig:set_pos(vector.add(pos, session.cam_offset))
	session.rig:set_velocity(vector.zero())
	session.last_pos = pos
	session.last_x, session.last_z = nil, nil
	session.was_grounded = nil
	session.prev_vel_y = 0
	session.shift = nil
	set_surface(session, pos.z > SLICE_Z + 0.5)
end

-- True while the machine drives the surface behind the slice (or glides between the two), where slice tools do nothing
function str_machine.is_surface(player)
	local session = sessions[player:get_player_name()]
	return session ~= nil and (session.surface or session.shift) ~= nil
end

-- For slice tools: in surface mode, tells the player and returns true
function str_machine.blocked_on_surface(player)
	if not str_machine.is_surface(player) then
		return false
	end
	str_utils.show_popup(player:get_player_name(), "Not available in surface mode.", 2, true)
	return true
end

function str_machine.is_dead(player)
	local session = sessions[player:get_player_name()]
	return session ~= nil and session.destroyed == true
end

function str_machine.destroy(player)
	local name = player:get_player_name()
	local session = sessions[name]
	if (session and session.destroyed) or str_mode.get(player) ~= "vehicle" then
		return
	end
	if player:get_meta():get_string(DEATH_MAIL_KEY) == "" then
		player:get_meta():set_string(DEATH_MAIL_KEY, "1")
		str_mail.send_story(name, "jim_death")
	end
	-- The penalty is applied at once so it survives leaving during the death screen
	cargo.clear(player)
	str_machine.hull_slots.clear(player)
	str_machine.heat.reset(player)
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
		str_utils.puff(pos, EXPLOSION_PARTICLES, 1, EXHAUST_TEXTURE, true)
	end
	-- The camera rig stays so the view is frozen where the machine blew up
	session.obj:remove()
	session.rig:set_velocity(vector.zero())
	str_environment.set_player_lighting(player, {saturation = 0})
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
	str_environment.set_player_lighting(player)
	str_environment.update(player, START_POS.y, light.light_fade_end, light.vignette_max, light.light_min)
	spawn_at(name, START_POS)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= DEATH_FORM then
		return
	end
	if fields.respawn then
		respawn(player)
	elseif fields.quit and str_machine.is_dead(player) then
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

str_mode.register_mode("vehicle", {
	on_enter = function(player)
		local name = player:get_player_name()
		local session = sessions[name]
		if session and not session.destroyed and session.obj:get_pos() and session.rig:get_pos() then
			place_camera(session, CAM_START_DISTANCE)
			session.rig:set_pos(vector.add(session.obj:get_pos(), session.cam_offset))
			board(player, session)
			-- Again next step: the client's own look can overwrite the first one when boarding mid-click
			core.after(0, function()
				local current = player:is_valid() and str_mode.get(player) == "vehicle" and sessions[name]
				if current then
					reset_look(player, current)
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
			str_environment.set_player_lighting(player)
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
			if entity.name:sub(1, #"str_machine:") ~= "str_machine:" and not entity.keep_on_clear then
				doomed[#doomed + 1] = entity.object
			end
		end
		for _, obj in ipairs(doomed) do
			obj:remove()
		end
		core.log("action", name .. " clears objects (" .. #doomed .. " loaded, skipping str_machine).")
		return true, "Cleared " .. #doomed .. " loaded objects."
	end,
})
