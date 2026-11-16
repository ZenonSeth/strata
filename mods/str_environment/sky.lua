local sky = {}

-- At and below these y values the sky bodies / the clouds are hidden
local HIDE_BODIES_AT = -10
local HIDE_CLOUDS_AT = -20
-- Matches fog FADE_END, where the sky is fully black
local HIDE_SUN_AT = -50

local THEMES = {
	warm_morning = {day_sky = "#7099cc", day_horizon = "#f2d9b0"},
	dark_hazy = {day_sky = "#5f7690", day_horizon = "#a89f94"},
	clean = {day_sky = "#2f7fd6", day_horizon = "#bfe3f5"},
}
local THEME = "dark_hazy"

local theme = THEMES[THEME]
local function rgb(spec)
	local c = core.colorspec_to_table(spec)
	return {r = c.r, g = c.g, b = c.b}
end
sky.DAY_SKY = rgb(theme.day_sky)
sky.DAY_HORIZON = rgb(theme.day_horizon)

local bodies_shown = {}
local clouds_shown = {}
local sun_shown = {}

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

	local show_sun = y > HIDE_SUN_AT
	if sun_shown[name] ~= show_sun then
		sun_shown[name] = show_sun
		player:set_sun({visible = show_sun, sunrise_visible = show_sun})
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
	sun_shown[name] = nil
end

str_environment.sky = sky
