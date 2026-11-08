local player_lighting = {}

local BASE = {
	shadows = {intensity = 0.33},
	bloom = {intensity = 0.1},
	volumetric_light = {strength = 0.2},
	exposure = {
		luminance_min = -3.5,
		luminance_max = -2.5,
		exposure_correction = 0.35,
		speed_dark_bright = 1500,
		speed_bright_dark = 700,
	},
	saturation = 1.1,
}

-- Applies BASE with overrides on top, e.g. {saturation = 0.6, exposure = {exposure_correction = 0}}
function player_lighting.apply(player, overrides)
	local light = table.copy(BASE)
	for key, value in pairs(overrides or {}) do
		if type(value) == "table" then
			light[key] = light[key] or {}
			for field, field_value in pairs(value) do
				light[key][field] = field_value
			end
		else
			light[key] = value
		end
	end
	player:set_lighting(light)
end

return player_lighting
