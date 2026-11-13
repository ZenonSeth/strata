-- Loads strata, materials, gems, formations and caverns and scales their depths (also loaded by the mapgen script).
-- The data files are unscaled metres; the world is DEPTH_SCALE times that.
local DEPTH_SCALE = 0.25
-- Multiply every material density (ores and liquids) and every gem rarity (strange objects are exempt)
local ORE_DENSITY_SCALE = 1
local GEM_RARITY_SCALE = 0.75

local path = core.get_modpath("str_nodes")
local data = {
	depth_scale = DEPTH_SCALE,
	max_overlap = math.floor(1000 * DEPTH_SCALE + 0.5),
	strata = dofile(path .. "/strata.lua"),
	materials = dofile(path .. "/materials.lua"),
	gems = dofile(path .. "/gems.lua"),
	formations = dofile(path .. "/formations.lua"),
	caverns = dofile(path .. "/caverns.lua"),
	-- Mesh variants per formation (str_nodes_rock_<n>.obj)
	formation_variants = 3,
}

-- Ores and gems are registered once per host stratum; both sides must agree on the names
function data.ore_node(material, richness, stratum)
	return "str_nodes:ore_" .. material .. "_" .. richness .. "_in_" .. stratum
end

function data.gem_node(gem, stratum)
	return "str_nodes:gem_" .. gem .. "_in_" .. stratum
end

function data.formation_node(formation, variant)
	return "str_nodes:formation_" .. formation .. "_" .. variant
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
-- Strange objects are placed like gems but are not scaled with them
for _, g in ipairs(dofile(path .. "/relics.lua")) do
	data.gems[#data.gems + 1] = g
end

for _, list in ipairs({data.materials, data.gems, data.formations, {data.caverns}}) do
	for _, m in ipairs(list) do
		for _, point in ipairs(m.curve) do
			point[1] = scaled(point[1])
		end
	end
end

return data
