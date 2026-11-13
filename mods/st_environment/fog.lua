local fog = {}

-- Fixed span, independent of the lights upgrades; override is off at and above FADE_START
local FADE_START = -10
local FADE_END = -50
local START_COLOR = st_environment.sky.DAY_HORIZON
local STEP = 0.02

local sent = {}

local function brightness_at(y)
	local t = math.max(0, math.min((y - FADE_END) / (FADE_START - FADE_END), 1))
	local eased = t * t * (3 - 2 * t)
	return math.floor(eased / STEP + 0.5) * STEP
end

function fog.update(player, y)
	local value = y >= FADE_START and -1 or brightness_at(y)
	local name = player:get_player_name()
	if sent[name] == value then
		return
	end
	sent[name] = value
	local color = "#00000000"
	if value >= 0 then
		color = string.format("#%02x%02x%02x",
			math.floor(START_COLOR.r * value + 0.5),
			math.floor(START_COLOR.g * value + 0.5),
			math.floor(START_COLOR.b * value + 0.5))
	end
	player:set_sky({fog = {fog_color = color}})
end

function fog.forget(player)
	sent[player:get_player_name()] = nil
end

core.register_globalstep(function()
	for _, player in ipairs(core.get_connected_players()) do
		fog.update(player, player:get_pos().y)
	end
end)

st_environment.fog = fog
