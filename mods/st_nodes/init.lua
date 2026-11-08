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

-- Strata, materials and gems come from the data files

local modpath = core.get_modpath("st_nodes")
local data = dofile(modpath .. "/data.lua")
local strata, materials, gems = data.strata, data.materials, data.gems

local MAX_OVERLAP = data.max_overlap
local WORLD_SCALE = 1
local ORE_BASE_COLOR = "#707070"
local ORE_RICHNESS = {
	{name = "poor", yield = 1, hardness = 1, mark = 4},
	{name = "regular", yield = 2, hardness = 1.15, mark = 8},
	{name = "rich", yield = 3, hardness = 1.3, mark = 12},
}

for i, s in ipairs(strata) do
	local nxt = strata[i + 1]
	assert(not s.to or s.to > s.from, "strata: " .. s.name .. " ends before it starts")
	if nxt then
		assert(nxt.from > s.from and nxt.tier >= s.tier, "strata: bad order at " .. nxt.name)
		assert(s.to and s.to - nxt.from <= MAX_OVERLAP, "strata: overlap too big at " .. nxt.name)
		if strata[i + 2] then
			assert(s.to <= strata[i + 2].from, "strata: " .. s.name .. " overlaps a non-neighbour")
		end
	end
end

local function tier_hardness(tier)
	local t = (tier - 1) / 9
	local h = DIRT_HARDNESS_TOP * (DIRT_HARDNESS_DEEP / DIRT_HARDNESS_TOP) ^ t
	return math.floor(h * 100 + 0.5) / 100
end

local function has_texture(file)
	local f = io.open(modpath .. "/textures/" .. file, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

local function hsv_color(h, s, v)
	local out = "#"
	for _, n in ipairs({5, 3, 1}) do
		local k = (n + h * 6) % 6
		local c = v - v * s * math.max(0, math.min(k, 4 - k, 1))
		out = out .. string.format("%02x", math.floor(c * 255 + 0.5))
	end
	return out
end

local function name_color(name)
	local h = 0
	for i = 1, #name do
		h = (h * 31 + name:byte(i)) % 360
	end
	return hsv_color(h / 360, 0.6, 0.85)
end

local function world_tile(file)
	return {name = file, align_style = "world", scale = WORLD_SCALE}
end

-- Rock: world-aligned texture if the file exists, else a flat colour that darkens with depth
for i, s in ipairs(strata) do
	local file = "st_nodes_rock_" .. s.name .. ".png"
	local tile
	if has_texture(file) then
		tile = world_tile(file)
	else
		tile = fill(lerp_color({0xb0, 0x95, 0x6a}, {0x30, 0x28, 0x2c}, (i - 1) / (#strata - 1)))
	end
	core.register_node("st_nodes:" .. s.name, {
		description = s.description,
		tiles = {tile},
		groups = {oddly_breakable_by_hand = 1},
		st_tier = s.tier,
		st_hardness = tier_hardness(s.tier),
	})
end

-- Ore and gems: neutral base with an overlay texture, or a marked square as a placeholder
local function register_embedded(node_name, description, file, color, mark, def)
	local base_file = "st_nodes_ore_base.png"
	if has_texture(file) then
		def.tiles = {has_texture(base_file) and world_tile(base_file) or fill(ORE_BASE_COLOR)}
		def.overlay_tiles = {world_tile(file)}
	else
		local offset = (16 - mark) / 2
		def.tiles = {fill(ORE_BASE_COLOR) .. "^[fill:" .. mark .. "x" .. mark .. ":" ..
			offset .. "," .. offset .. ":" .. color}
	end
	def.description = description
	def.groups = {oddly_breakable_by_hand = 1}
	core.register_node(node_name, def)
end

for _, m in ipairs(materials) do
	if not m.liquid then
		for _, r in ipairs(ORE_RICHNESS) do
			register_embedded("st_nodes:ore_" .. m.name .. "_" .. r.name,
				m.description .. " (" .. r.name .. ")",
				"st_nodes_ore_" .. m.name .. "_" .. r.name .. ".png", name_color(m.name), r.mark, {
					st_material = m.name,
					st_tier = m.tier,
					st_yield = r.yield,
					st_hardness = math.floor(tier_hardness(m.tier) * r.hardness * 100 + 0.5) / 100,
				})
		end
	end
end

for _, g in ipairs(gems) do
	register_embedded("st_nodes:gem_" .. g.name, g.description,
		"st_nodes_gem_" .. g.name .. ".png", name_color(g.name), 6, {
			st_material = g.name,
			st_tier = g.tier,
			st_yield = 1,
			st_hardness = tier_hardness(g.tier),
		})
end

-- Liquids: only source nodes are collected, they never renew
local LIQUIDS = {
	oil = {viscosity = 3, color = "#1c1a14", light = 0},
	lava = {viscosity = 5, color = "#e8501a", light = 13, damage = 4},
}

for _, m in ipairs(materials) do
	local l = LIQUIDS[m.name]
	if m.liquid and l then
		local file = "st_nodes_liquid_" .. m.name .. ".png"
		local tex = has_texture(file) and file or fill(l.color)
		local common = {
			tiles = {tex},
			special_tiles = {{name = tex, backface_culling = false}, {name = tex, backface_culling = false}},
			use_texture_alpha = "opaque",
			paramtype = "light",
			light_source = l.light,
			walkable = false,
			pointable = true,
			diggable = false,
			buildable_to = true,
			is_ground_content = false,
			drop = "",
			liquid_viscosity = l.viscosity,
			liquid_renewable = false,
			damage_per_second = l.damage,
			groups = {liquid = 1},
			st_material = m.name,
		}
		local function make(extra)
			local def = table.copy(common)
			for k, v in pairs(extra) do
				def[k] = v
			end
			return def
		end
		local source = "st_nodes:" .. m.name .. "_source"
		local flowing = "st_nodes:" .. m.name .. "_flowing"
		core.register_node(source, make({
			description = m.description,
			drawtype = "liquid",
			liquidtype = "source",
			liquid_alternative_flowing = flowing,
			liquid_alternative_source = source,
			st_yield = 1,
		}))
		core.register_node(flowing, make({
			description = "Flowing " .. m.description:lower(),
			drawtype = "flowingliquid",
			paramtype2 = "flowingliquid",
			liquidtype = "flowing",
			liquid_alternative_flowing = flowing,
			liquid_alternative_source = source,
		}))
	end
end
