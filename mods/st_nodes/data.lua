-- Loads strata, materials and gems and scales their depths (also loaded by the mapgen script).
-- The data files are unscaled metres; the world is DEPTH_SCALE times that.
local DEPTH_SCALE = 0.25
-- Multiply every material density (ores and liquids) and every gem rarity
local ORE_DENSITY_SCALE = 3
local GEM_RARITY_SCALE = 4

local path = core.get_modpath("st_nodes")
local data = {
	depth_scale = DEPTH_SCALE,
	max_overlap = math.floor(1000 * DEPTH_SCALE + 0.5),
	strata = dofile(path .. "/strata.lua"),
	materials = dofile(path .. "/materials.lua"),
	gems = dofile(path .. "/gems.lua"),
}

-- Ores and gems are registered once per host stratum; both sides must agree on the names
function data.ore_node(material, richness, stratum)
	return "st_nodes:ore_" .. material .. "_" .. richness .. "_in_" .. stratum
end

function data.gem_node(gem, stratum)
	return "st_nodes:gem_" .. gem .. "_in_" .. stratum
end

local function scaled(depth)
	return math.floor(depth * DEPTH_SCALE + 0.5)
end

for _, s in ipairs(data.strata) do
	s.from = scaled(s.from)
	s.to = s.to and scaled(s.to)
end

for _, m in ipairs(data.materials) do
	m.density = m.density * ORE_DENSITY_SCALE
end
for _, g in ipairs(data.gems) do
	g.rarity = g.rarity * GEM_RARITY_SCALE
end

for _, list in ipairs({data.materials, data.gems}) do
	for _, m in ipairs(list) do
		for _, point in ipairs(m.curve) do
			point[1] = scaled(point[1])
		end
	end
end

return data
