local lighting = {}

-- Full daylight at and above FADE_START; none at and below the fade_end passed to update
local FADE_START = -10
-- Ratios are rounded to this step so the client is only updated a few dozen times
local RATIO_STEP = 0.02

local sent = {}

local function ratio_at(y, fade_end)
	local span = math.max(FADE_START - fade_end, 1)
	local t = math.max(0, math.min((y - fade_end) / span, 1))
	return math.floor(t / RATIO_STEP + 0.5) * RATIO_STEP
end

-- Above FADE_START the natural day/night cycle runs (no override); below it the cycle fades out
-- Returns the current ratio
function lighting.update(player, y, fade_end, light_min)
	local natural = core.time_to_day_night_ratio(core.get_timeofday())
	local name = player:get_player_name()
	local ratio = natural
	local override = nil
	if y < FADE_START then
		local depth = ratio_at(y, fade_end)
		ratio = math.floor(math.max(depth * natural, light_min or 0) / RATIO_STEP + 0.5) * RATIO_STEP
		override = ratio
	end
	local key = override or -1
	if sent[name] ~= key then
		sent[name] = key
		player:override_day_night_ratio(override)
	end
	return ratio
end

function lighting.forget(player)
	sent[player:get_player_name()] = nil
end

st_environment.lighting = lighting
