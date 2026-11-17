local constants = dofile(core.get_modpath("str_utils") .. "/constants.lua")
local surface_y = constants.surface_y
local slice_z = constants.slice_z
local half_width = constants.world_half_width

local terrain = dofile(core.get_modpath("str_worldgen") .. "/terrain.lua")
local hill_map, edge_map, biome_at = terrain.hill_map, terrain.edge_map, terrain.biome_at
local HILL_TOP, BACK_DEPTH, world_seed = terrain.HILL_TOP, terrain.BACK_DEPTH, terrain.world_seed

local data = {}
local param2 = {}

core.register_on_generated(function(vm, minp, maxp)
	vm:get_data(data)
	vm:get_param2_data(param2)
	terrain.generate(data, param2, VoxelArea(vm:get_emerged_area()), minp, maxp,
		(core.ipc_get("str_worldgen:cycles") or {})[slice_z] or 0)
	vm:set_data(data)
	vm:set_param2_data(param2)
	vm:calc_lighting()
end)

-- Writes {x, y, content id, z (default: the slice)} entries into generated chunks
local function make_placer(nodes)
	return function(vm, minp, maxp)
		local area
		for _, n in ipairs(nodes) do
			local x, y, id, z = n[1], n[2], n[3], n[4] or slice_z
			if x >= minp.x and x <= maxp.x and y >= minp.y and y <= maxp.y
					and z >= minp.z and z <= maxp.z then
				if not area then
					vm:get_data(data)
					area = VoxelArea(vm:get_emerged_area())
				end
				data[area:index(x, y, z)] = id
			end
		end
		if area then
			vm:set_data(data)
			vm:calc_lighting()
		end
	end
end

-- Surface buildings, one z behind the slice on top of the ground, with a pad in front of each
-- part replacing the ground node in the slice. Part columns are given left to right, bottom up;
-- every pad is active (a str_pads id, set in init.lua) so the machine can use any of them.
local MAIN_X = constants.shop_x
local REFINERY_X = constants.refinery_x
local CONTACT_X = constants.contact_x
local buildings = {}
do
	local function id(name)
		return core.get_content_id(name)
	end
	local function building(x, columns, pad_id)
		for dx, column in ipairs(columns) do
			for dy, part in ipairs(column) do
				buildings[#buildings + 1] = {x + dx - 1, surface_y + dy, id("str_buildings:" .. part), slice_z + 1}
			end
			buildings[#buildings + 1] = {x + dx - 1, surface_y, id("str_pads:pad_" .. pad_id)}
		end
	end
	-- Mechanic shop and home: extension, main building with the entrance, annex
	building(MAIN_X - 1, {{"main_ext"}, {"main"}, {"annex"}}, "shop")
	-- Ore refinery: furnace and chimney, hatch and tank
	building(REFINERY_X, {{"refinery_ll", "refinery_ul"}, {"refinery_lr", "refinery_ur"}}, "refinery")
	-- Company contact: office with the entrance, storage to its right
	building(CONTACT_X, {{"contact_office"}, {"contact_storage"}}, "contact")
end
-- Surface decoration, only behind the slice, one node per cell. Trees win over bushes, bushes over
-- grass tufts. Trees and bushes grow in clumps: smooth 2D noise over (x, z), a patch where it is
-- above the first level and denser as it rises. Tufts are scattered evenly. The biome picks the look.
local DECOR_DEPTH = BACK_DEPTH
local TUFT_DENSITY = 0.3
local TUFT_VARIANTS = 3
-- {noise (0..1) above, chance per cell}, low to high
local TREE_LEVELS = {{0.50, 0.05}, {0.60, 0.12}, {0.70, 0.22}}
local BUSH_LEVELS = {{0.75, 0.08}, {0.83, 0.22}, {0.91, 0.45}}
local function patch_noise(seed, spread)
	return {
		offset = 0, scale = 1, spread = {x = spread, y = spread, z = spread},
		-- The class does not add the world seed
		seed = (seed + world_seed) % 2147483647, octaves = 1, persist = 0.5, lacunarity = 2,
	}
end
local TREE_NOISE = patch_noise(4311, 100)
local BUSH_NOISE = patch_noise(9127, 60)

local function patch_chance(levels, n)
	local u = 0.5 + n * 0.5
	local chance = 0
	for _, level in ipairs(levels) do
		if u > level[1] then
			chance = level[2]
		end
	end
	return chance
end

local BIOMES = {"grass", "snow", "sand"}
local TREE_KIND = {grass = "oak", snow = "pine", sand = "cactus"}
local TREE_TOPS = {oak = 2, pine = 1, cactus = 2}
local tufts, bushes, trees = {}, {}, {}
for _, biome in ipairs(BIOMES) do
	tufts[biome], bushes[biome] = {}, {}
	for v = 1, TUFT_VARIANTS do
		tufts[biome][v] = core.get_content_id("str_decor:tuft_" .. biome .. "_" .. v)
	end
	for v = 1, 2 do
		bushes[biome][v] = core.get_content_id("str_decor:bush_" .. biome .. "_" .. v)
	end
	local kind = TREE_KIND[biome]
	trees[biome] = {base = core.get_content_id("str_decor:tree_" .. kind .. "_base"), tops = {}}
	for v = 1, TREE_TOPS[kind] do
		trees[biome].tops[v] = core.get_content_id("str_decor:tree_" .. kind .. "_" .. v .. "_top")
	end
end

-- Stable 0..1 per cell and salt, independent of how the world is cut into chunks
local function cell_random(x, z, salt)
	local s = math.sin(x * 12.9898 + z * 78.233 + (salt + world_seed % 10007) * 37.719) * 43758.5453
	return s - math.floor(s)
end

-- Cells within 1 of a building (x columns, and the z rows in front of and behind it) stay bare
local keep_clear_x = {}
for _, n in ipairs(buildings) do
	if n[4] then
		for x = n[1] - 1, n[1] + 1 do
			keep_clear_x[x] = true
		end
	end
end
local CLEAR_Z_MAX = slice_z + 2

core.register_on_generated(function(vm, minp, maxp)
	local z0, z1 = math.max(minp.z, slice_z + 1), math.min(maxp.z, slice_z + DECOR_DEPTH)
	if maxp.y <= surface_y or minp.y > HILL_TOP + 1 or z0 > z1 then
		return
	end
	vm:get_data(data)
	vm:get_param2_data(param2)
	local area = VoxelArea(vm:get_emerged_area())
	local size = {x = maxp.x - minp.x + 1, y = z1 - z0 + 1, z = 1}
	local tree_map = ValueNoiseMap(TREE_NOISE, size):get_2d_map_flat({x = minp.x, y = z0})
	local bush_map = ValueNoiseMap(BUSH_NOISE, size):get_2d_map_flat({x = minp.x, y = z0})
	local hills = hill_map(minp.x, maxp.x, z0, z1)
	local edges = edge_map(minp.x, maxp.x, z0, z1)
	for z = z0, z1 do
		for x = math.max(minp.x, -half_width), math.min(maxp.x, half_width) do
			local ni = (z - z0) * size.x + (x - minp.x) + 1
			local y = surface_y + 1 + hills[ni]
			local biome = biome_at(x, edges[ni])
			local inside = y >= minp.y and y <= maxp.y
			local i = inside and area:index(x, y, z)
			local free = inside and not (z <= CLEAR_Z_MAX and keep_clear_x[x])
			if free and y < maxp.y and cell_random(x, z, 4) < patch_chance(TREE_LEVELS, tree_map[ni]) then
				local tree = trees[biome]
				data[i] = tree.base
				param2[i] = math.floor(cell_random(x, z, 6) * 4)
				local j = area:index(x, y + 1, z)
				data[j] = tree.tops[math.floor(cell_random(x, z, 5) * #tree.tops) + 1]
				param2[j] = param2[i]
			elseif free and cell_random(x, z, 7) < patch_chance(BUSH_LEVELS, bush_map[ni]) then
				data[i] = bushes[biome][math.floor(cell_random(x, z, 8) * #bushes[biome]) + 1]
				param2[i] = math.floor(cell_random(x, z, 9) * 4)
			elseif free and cell_random(x, z, 1) < TUFT_DENSITY then
				data[i] = tufts[biome][math.floor(cell_random(x, z, 2) * TUFT_VARIANTS) + 1]
				-- meshoptions: plant shape 0-3 plus 8, a small random horizontal offset
				param2[i] = 8 + math.floor(cell_random(x, z, 3) * 4)
			end
		end
	end
	vm:set_data(data)
	vm:set_param2_data(param2)
	vm:calc_lighting()
end)

core.register_on_generated(make_placer(buildings))
