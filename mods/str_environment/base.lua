local lighting = str_environment.lighting
local vignette = str_environment.vignette
local sky = str_environment.sky
local player_lighting = str_environment.player_lighting

-- y is the machine's height; call it every step, it only sends changes.
-- fade_end is the y of full darkness and max_opacity the vignette strength there.
-- light_min is the lowest day/night ratio the darkness can bring the world to.
-- Returns the day/night ratio (0..1), which is the world's light level.
function str_environment.update(player, y, fade_end, max_opacity, light_min)
	local ratio = lighting.update(player, y, fade_end, light_min)
	vignette.update(player, y, fade_end, max_opacity, ratio)
	sky.update(player, y)
	return ratio
end

-- Base look plus optional overrides, for depth layers that change it
str_environment.set_player_lighting = player_lighting.apply

-- Day/night cycle is off for now: time is frozen at 7am
core.settings:set("time_speed", "0")

core.register_on_joinplayer(function(player)
	core.set_timeofday(7 / 24)
	player_lighting.apply(player)
	-- Invisible sun that still casts shadows
	player:set_sun({texture = "blank.png"})
end)

core.register_on_leaveplayer(function(player)
	lighting.forget(player)
	vignette.forget(player)
	sky.forget(player)
	str_environment.fog.forget(player)
end)
