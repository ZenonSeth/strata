local constants = str_utils.constants
local GAS = constants.gas
local SCALE = str_nodes.data.depth_scale

local START = GAS.start_depth * SCALE
local BOTTOM = constants.world_depth * SCALE
local WARN_AT = (GAS.start_depth - GAS.warning_distance) * SCALE
local MAIL_ID = "jim_gas"

-- Base names of plain stratum rock; ores, gems, formations and liquids are separate nodes
local stratum_nodes = {}
for _, s in ipairs(str_nodes.data.strata) do
	stratum_nodes["str_nodes:" .. s.name] = true
end

str_audio.sfx.register("gas_blast", {sound = "str_explosives_blast", max_hear_distance = 48})

-- 0 at the start depth, 1 at the world bottom; nil above the start
local function progress(depth)
	if depth < START then
		return nil
	end
	return math.min((depth - START) / (BOTTOM - START), 1)
end

-- Grows geometrically, so the chance stays low for most of the range
function str_gas.chance(depth)
	local t = progress(depth)
	return t and GAS.min_chance * (GAS.max_chance / GAS.min_chance) ^ t or 0
end

function str_gas.damage(depth)
	local t = progress(depth) or 0
	return GAS.damage * (1 + (GAS.max_damage_mult - 1) * t)
end

local function depth_of(pos)
	return constants.surface_y - math.floor(pos.y + 0.5)
end

local FLAME_COLORS = {"#ffb040", "#ff7020", "#e04010", "#6a5a50"}

local function spawn_burst(pos)
	for _ = 1, 30 do
		local dir = vector.new(math.random() - 0.5, math.random() - 0.5, (math.random() - 0.5) * 0.3)
		core.add_particle({
			pos = vector.add(pos, vector.multiply(dir, 0.5)),
			velocity = vector.multiply(dir, 6 + math.random() * 4),
			acceleration = vector.new(0, 1, 0),
			expirationtime = 0.5 + math.random() * 0.5,
			size = 6 + math.random() * 6,
			texture = {name = "str_machine_puff.png^[multiply:" .. FLAME_COLORS[math.random(#FLAME_COLORS)],
				blend = "alpha", alpha_tween = {1, 0}, scale_tween = {0.8, 2.5}},
		})
	end
end

-- Neighbours are destroyed as a blast, so they never set off further pockets
function str_gas.explode(player, pos)
	str_audio.sfx.play("gas_blast", {pos = pos})
	spawn_burst(pos)
	local tier = str_machine.stats.get(player).drill_tier
	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				str_machine.destroy_node(player, vector.offset(pos, dx, dy, 0), tier)
			end
		end
	end
	str_utils.show_popup(player:get_player_name(), "GAS POCKET!", 2, false, {color = 0xFF4500, size = 1.25})
	str_machine.hull.damage(player, str_gas.damage(depth_of(pos)))
end

str_machine.register_on_dig(function(player, pos, node_name, method)
	if method ~= "drill" then
		return
	end
	local def = core.registered_nodes[node_name]
	if not stratum_nodes[def and def.str_base or node_name] then
		return
	end
	if math.random() >= str_gas.chance(depth_of(pos)) then
		return
	end
	-- Deferred so the blast and a possible machine loss happen outside the dig step
	local name = player:get_player_name()
	pos = vector.copy(pos)
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if p and str_mode.get(p) == "vehicle" and not str_machine.is_dead(p) then
			str_gas.explode(p, pos)
		end
	end)
end)

str_machine.register_on_depth_change(function(player, depth)
	if depth >= WARN_AT then
		str_mail.send_story(player:get_player_name(), MAIL_ID)
	end
end)
