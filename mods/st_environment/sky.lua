local sky = {}

-- At and below these y values the sky bodies / the clouds are hidden
local HIDE_BODIES_AT = -10
local HIDE_CLOUDS_AT = -20

local bodies_shown = {}
local clouds_shown = {}

function sky.update(player, y)
	local name = player:get_player_name()

	local show_bodies = y > HIDE_BODIES_AT
	if bodies_shown[name] ~= show_bodies then
		bodies_shown[name] = show_bodies
		if show_bodies then
			-- player:set_sun()
			player:set_moon()
			player:set_stars()
		else
			-- player:set_sun({visible = false, sunrise_visible = false})
			player:set_moon({visible = false})
			player:set_stars({visible = false})
		end
	end

	local show_clouds = y > HIDE_CLOUDS_AT
	if clouds_shown[name] ~= show_clouds then
		clouds_shown[name] = show_clouds
		if show_clouds then
			player:set_clouds()
		else
			player:set_clouds({density = 0})
		end
	end
end

function sky.forget(player)
	local name = player:get_player_name()
	bodies_shown[name] = nil
	clouds_shown[name] = nil
end

return sky
