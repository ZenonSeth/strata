local fog = {}

-- Fixed span, independent of the lights upgrades; override is off at and above FADE_START
local FADE_START = -10
local FADE_END = -50
local DAY_SKY = str_environment.sky.DAY_SKY
local DAY_HORIZON = str_environment.sky.DAY_HORIZON
local STEP = 0.02

local sent = {}

local function brightness_at(y)
	local t = math.max(0, math.min((y - FADE_END) / (FADE_START - FADE_END), 1))
	local eased = t * t * (3 - 2 * t)
	return math.floor(eased / STEP + 0.5) * STEP
end

local function scaled(color, value)
	return string.format("#%02x%02x%02x",
		math.floor(color.r * value + 0.5),
		math.floor(color.g * value + 0.5),
		math.floor(color.b * value + 0.5))
end

-- Fog and the custom sky colors darken together, to black at FADE_END
function fog.update(player, y)
	local value = y >= FADE_START and -1 or brightness_at(y)
	local name = player:get_player_name()
	if sent[name] == value then
		return
	end
	sent[name] = value
	local brightness = value >= 0 and value or 1
	player:set_sky({
		fog = {fog_color = value >= 0 and scaled(DAY_HORIZON, value) or "#00000000"},
		sky_color = {
			day_sky = scaled(DAY_SKY, brightness),
			day_horizon = scaled(DAY_HORIZON, brightness),
		},
	})
end

function fog.forget(player)
	sent[player:get_player_name()] = nil
end

core.register_globalstep(function()
	for _, player in ipairs(core.get_connected_players()) do
		fog.update(player, player:get_pos().y)
	end
end)

str_environment.fog = fog
