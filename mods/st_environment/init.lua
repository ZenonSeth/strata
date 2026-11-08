st_environment = {}

local modpath = core.get_modpath("st_environment")
local lighting = dofile(modpath .. "/lighting.lua")
local vignette = dofile(modpath .. "/vignette.lua")
local sky = dofile(modpath .. "/sky.lua")
local player_lighting = dofile(modpath .. "/player_lighting.lua")

-- y is the machine's height; call it every step, it only sends changes.
-- fade_end is the y of full darkness and max_opacity the vignette strength there.
-- Returns the day/night ratio (0..1), which is the world's light level.
function st_environment.update(player, y, fade_end, max_opacity)
	local ratio = lighting.update(player, y, fade_end)
	vignette.update(player, y, fade_end, max_opacity)
	sky.update(player, y)
	return ratio
end

-- Base look plus optional overrides, for depth layers that change it
st_environment.set_player_lighting = player_lighting.apply

core.register_on_joinplayer(function(player)
	-- Permanent daylight until the machine goes below y = -10
	player:override_day_night_ratio(1)
	player_lighting.apply(player)
	-- Invisible sun that still casts shadows
	player:set_sun({texture = "blank.png"})
end)

core.register_on_leaveplayer(function(player)
	lighting.forget(player)
	vignette.forget(player)
	sky.forget(player)
end)
