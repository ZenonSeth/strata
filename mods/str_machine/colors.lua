-- Model textures: each glb texture slot gets a solid color, a fixed texture, a player-picked color or an upgrade look
local colors = {}

local META_KEY = "str_machine:colors"

colors.defaults = {frame = "#34373b", panel = "#8a8d91", spokes = "#aaacb0", thruster = "#55585c", ladder = "#7a671d"}

local THRUSTER_INNER = {propeller = "#3c3e42", jet = "#6f7f94", rocket = "#a5552e"}
-- Drill level name -> cone texture
local DRILL_TEXTURES = {}
for _, level in ipairs(str_machine_data.get_upgrade("drill").levels) do
	DRILL_TEXTURES[level.name] = "str_machine_drill_" .. level.name .. ".png"
end
local HULL_LEVELS = {}
for _, level in ipairs(str_machine_data.get_upgrade("hull").levels) do
	HULL_LEVELS[level.name] = true
end

-- Near-white noise tinted by a fixed color
local function noise(hex)
	return {texture = "str_machine_noise.png", tint = hex}
end

-- Keyed by glb texture name: a color, a colors.defaults key, {texture, tint = key or color}, {texture, thruster_kind},
-- {drill} or {hull = texture prefix, tint}
local MODEL_COLORS = {
	rear_drive_shaft = noise("#393c3e"),
	rear_differential = noise("#505152"),
	gas_strut_lower = noise("#676b6f"),
	gast_strut = noise("#505152"),
	drive_shaft_rear = noise("#393c3e"),
	metal_front_support = noise("#64686e"),
	gas_strut_front_bottom = noise("#676b6f"),
	gas_strut_front_top = noise("#505152"),
	chassis_front_top = {hull = "str_machine_chassis_front_top_", tint = "panel"},
	chassis_rear = {hull = "str_machine_chassis_rear_", tint = "panel"},
	chassis_front_bottom = {hull = "str_machine_chassis_front_bottom_", tint = "panel"},
	drill_metal_beam_for_rotating = noise("#505152"),
	gearbox_misc_under_carrige = noise("#434951"),
	metal_cylinder_gearbox = noise("#434951"),
	rear_to_front_drive_shaft = noise("#393c3e"),
	gearbox_misc_under_carrige_small = noise("#434951"),
	chassis_front_frame = {texture = "str_machine_chassis_front_frame.png", tint = "frame"},
	chassis_cockpit_front_glass = noise("#aad7f0"),
	drill_shaft = noise("#64686e"),
	right_drill = {drill = DRILL_TEXTURES},
	thruster_outer = {texture = "str_machine_thruster_outer.png", tint = "thruster"},
	thruster_inner = {texture = "str_machine_thruster_inner.png", thruster_kind = THRUSTER_INNER},
	ladder = {texture = "str_machine_noise.png", tint = "ladder"},
	right_tires = {texture = "str_machine_right_tires.png"},
	tire_spokes = {texture = "str_machine_noise.png", tint = "spokes"},
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

local function slot_texture(spec, chosen)
	if type(spec) == "string" then
		return "[fill:16x16:" .. (chosen[spec] or colors.defaults[spec] or spec)
	elseif spec.drill then
		return spec.drill[chosen.drill] or spec.drill.stock
	elseif spec.hull then
		return spec.hull .. (HULL_LEVELS[chosen.hull] and chosen.hull or "stock") .. ".png^[multiply:"
			.. (chosen[spec.tint] or colors.defaults[spec.tint])
	elseif spec.thruster_kind then
		return spec.texture .. "^[multiply:" .. (spec.thruster_kind[chosen.thruster_kind] or spec.thruster_kind.propeller)
	elseif spec.tint then
		return spec.texture .. "^[multiply:" .. (chosen[spec.tint] or colors.defaults[spec.tint] or spec.tint)
	end
	return spec.texture
end

-- Entity texture list for the given colors plus thruster_kind, drill and hull (defaults when nil or missing)
function colors.textures(chosen)
	chosen = chosen or {}
	local textures = {}
	for i, spec in ipairs(SLOT_COLORS) do
		textures[i] = slot_texture(spec, chosen)
	end
	return textures
end

str_machine.colors = colors
