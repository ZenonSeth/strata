-- Model colors: the glb texture slots are filled with solid colors; frame and panel are the player's choice
local colors = {}

local META_KEY = "str_machine:colors"
local LADDER_COLOR = "#9a8530"

colors.defaults = {frame = "#34373b", panel = "#8a8d91"}

-- Keyed by the glb texture name (without .png); "frame" and "panel" are the configurable ones
local MODEL_COLORS = {
	rear_drive_shaft = "#5a5f64",
	rear_differential = "#6e6e73",
	gas_strut_lower = "#8c9196",
	gast_strut = "#b9bec3",
	drive_shaft_rear = "#5a5f64",
	metal_front_support = "#64686e",
	gas_strut_front_bottom = "#8c9196",
	gas_strut_front_top = "#b9bec3",
	chassis_front_top = "panel",
	chassis_rear = "panel",
	chassis_front_bottom = "panel",
	drill_metal_beam_for_rotating = "#50545a",
	gearbox_misc_under_carrige = "#44474c",
	metal_cylinder_gearbox = "#44474c",
	rear_to_front_drive_shaft = "#50545a",
	gearbox_misc_under_carrige_small = "#44474c",
	chassis_front_frame = "frame",
	chassis_cockpit_front_glass = "#aad7f0",
	drill_shaft = "#3a3c40",
	left_drill = "#8a9097",
	right_drill = "#8a9097",
	thruster_outer = "#55585c",
	thruster_inner = "#3c3e42",
	ladder = LADDER_COLOR,
	right_tires = "#232326",
	tire_spokes = "#aaacb0",
}
local MISSING_COLOR = "#ff00ff"

-- Texture names of the model in slot order, read from the glb's JSON chunk
local function model_texture_names()
	local path = str_machine.modpath .. "/models/digger1.glb"
	local file = assert(io.open(path, "rb"))
	local data = file:read("*a")
	file:close()
	local b1, b2, b3, b4 = data:byte(13, 16)
	local json_len = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
	local gltf = assert(core.parse_json(data:sub(21, 20 + json_len)))
	local names = {}
	for i, texture in ipairs(gltf.textures) do
		names[i] = (texture.name or ""):gsub("%.png$", "")
	end
	return names
end

local SLOT_COLORS = {}
do
	local used = {}
	for i, name in ipairs(model_texture_names()) do
		if MODEL_COLORS[name] then
			used[name] = true
		else
			core.log("warning", "str_machine: no color for model texture '" .. name .. "'")
		end
		SLOT_COLORS[i] = MODEL_COLORS[name] or MISSING_COLOR
	end
	for name in pairs(MODEL_COLORS) do
		if not used[name] then
			core.log("warning", "str_machine: color entry '" .. name .. "' matches no model texture")
		end
	end
end

local function valid(hex)
	return type(hex) == "string" and hex:match("^#%x%x%x%x%x%x$") ~= nil
end

-- {frame = "#rrggbb", panel = "#rrggbb"}; player nil gives the defaults
function colors.get(player)
	local result = table.copy(colors.defaults)
	local raw = player and player:get_meta():get_string(META_KEY) or ""
	local data = raw ~= "" and core.parse_json(raw) or nil
	if type(data) == "table" then
		for key in pairs(result) do
			if valid(data[key]) then
				result[key] = data[key]
			end
		end
	end
	return result
end

function colors.set(player, key, hex)
	if not colors.defaults[key] or not valid(hex) then
		return false
	end
	local current = colors.get(player)
	current[key] = hex
	player:get_meta():set_string(META_KEY, core.write_json(current))
	return true
end

-- Entity texture list for the given colors (default colors when nil)
function colors.textures(chosen)
	chosen = chosen or colors.defaults
	local textures = {}
	for i, color in ipairs(SLOT_COLORS) do
		textures[i] = "[fill:16x16:" .. (chosen[color] or color)
	end
	return textures
end

str_machine.colors = colors
