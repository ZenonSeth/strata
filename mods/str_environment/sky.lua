local sky = {}

-- At and below these y values the sky bodies / the clouds are hidden
local HIDE_BODIES_AT = -10
local HIDE_CLOUDS_AT = -20

local THEMES = {
	warm_morning = {day_sky = "#7099cc", day_horizon = "#f2d9b0"},
	dark_hazy = {day_sky = "#5f7690", day_horizon = "#a89f94"},
	clean = {day_sky = "#2f7fd6", day_horizon = "#bfe3f5"},
}
local THEME = "dark_hazy"

local theme = THEMES[THEME]
local horizon = core.colorspec_to_table(theme.day_horizon)
sky.DAY_HORIZON = {r = horizon.r, g = horizon.g, b = horizon.b}

local bodies_shown = {}
local clouds_shown = {}
local colors_sent = {}

function sky.update(player, y)
	local name = player:get_player_name()

	if not colors_sent[name] then
		colors_sent[name] = true
		player:set_sky({sky_color = {
			day_sky = theme.day_sky,
			day_horizon = theme.day_horizon,
		}})
	end

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
	colors_sent[name] = nil
end

str_environment.sky = sky
