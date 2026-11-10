local constants = st_utils.constants
local world = st_nodes.data

-- Depth is measured like the HUD: nodes below the machine's start position
local ORIGIN_Y = constants.surface_y + 1
local MIN_DEPTH = 100
local MAX_DEPTH = constants.world_depth * world.depth_scale
local MIN_CHANCE = 0.02
local MAX_CHANCE = 0.25
-- Seconds between chance rolls, and the minimum quiet time after a sound starts
local CHECK_INTERVAL = 1
local COOLDOWN = 20
local GAIN = 0.8

st_audio.sfx.register("underground", {
	sound = "st_ambience_underground_sounds", category = "ambient", gain = GAIN,
})

local timer = 0
-- player name -> game time before which no new sound is rolled
local quiet_until = {}

local function chance_at(depth)
	local t = math.min(1, (depth - MIN_DEPTH) / (MAX_DEPTH - MIN_DEPTH))
	return MIN_CHANCE + (MAX_CHANCE - MIN_CHANCE) * t
end

core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < CHECK_INTERVAL then
		return
	end
	timer = timer - CHECK_INTERVAL
	local now = core.get_gametime()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local depth = ORIGIN_Y - player:get_pos().y
		if depth >= MIN_DEPTH and now >= (quiet_until[name] or 0)
				and math.random() < chance_at(depth) then
			st_audio.sfx.play("underground", {player = player})
			quiet_until[name] = now + COOLDOWN
		end
	end
end)

core.register_on_leaveplayer(function(player)
	quiet_until[player:get_player_name()] = nil
end)
