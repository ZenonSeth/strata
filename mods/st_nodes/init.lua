local DIRT_LEVELS = 10
local DIRT_COLOR_TOP = {0xa0, 0x76, 0x4a}
local DIRT_COLOR_DEEP = {0x3a, 0x2a, 0x20}
local DIRT_HARDNESS_TOP = 0.3
local DIRT_HARDNESS_DEEP = 6

local function fill(color)
	return "[fill:16x16:" .. color
end

local function lerp_color(a, b, t)
	local out = "#"
	for i = 1, 3 do
		out = out .. string.format("%02x", math.floor(a[i] + (b[i] - a[i]) * t + 0.5))
	end
	return out
end

for _, def in ipairs({
	{name = "soft", color = "#8b5a2b", hardness = 0.3},
	{name = "medium", color = "#808080", hardness = 1},
	{name = "hard", color = "#404050", hardness = 3},
}) do
	core.register_node("st_nodes:" .. def.name, {
		description = "Dig test node (" .. def.name .. ")",
		tiles = {fill(def.color)},
		groups = {oddly_breakable_by_hand = 1},
		st_hardness = def.hardness,
	})
end

core.register_node("st_nodes:sand", {
	description = "Sand",
	tiles = {fill("#e0cc8c")},
	groups = {oddly_breakable_by_hand = 1},
	st_hardness = 0.2,
})

for level = 1, DIRT_LEVELS do
	local t = (level - 1) / (DIRT_LEVELS - 1)
	local hardness = DIRT_HARDNESS_TOP * (DIRT_HARDNESS_DEEP / DIRT_HARDNESS_TOP) ^ t
	core.register_node("st_nodes:dirt_" .. level, {
		description = "Dirt (level " .. level .. ")",
		tiles = {fill(lerp_color(DIRT_COLOR_TOP, DIRT_COLOR_DEEP, t))},
		groups = {oddly_breakable_by_hand = 1},
		st_hardness = math.floor(hardness * 100 + 0.5) / 100,
	})
end
