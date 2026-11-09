-- Terrain exists only at and behind the gameplay slice, up to BACK_DEPTH behind it
local BACK_DEPTH = 100

local world = dofile(core.get_modpath("st_nodes") .. "/data.lua")
local constants = dofile(core.get_modpath("st_utils") .. "/constants.lua")
local surface_y = constants.surface_y
local slice_z = constants.slice_z
-- param2 that picks the darker palette entry of the rock nodes
local BACK_PARAM2 = 255
-- Surface biomes by x: snow west of SNOW_X, sand east of DESERT_X, grass between
local SNOW_X = -700
local DESERT_X = 700
local strata = world.strata

-- Picks the rock inside a stratum overlap. Flat in z, so the backing wall continues the slice.
local NOISE_SEED = 7751
local NOISE_PARAMS = {
	offset = 0, scale = 1,
	spread = {x = 300, y = 150 * world.depth_scale, z = 300},
	seed = NOISE_SEED, octaves = 3, persist = 0.5, lacunarity = 2,
}
-- The class does not add the world seed like core.get_value_noise_map would
NOISE_PARAMS.seed = (NOISE_SEED + (tonumber(core.get_mapgen_setting("seed")) or 0)) % 2147483647

local shapes = dofile(core.get_modpath("st_nodes") .. "/shapes.lua")

local c_grass = core.get_content_id("st_nodes:surface_grass")
local c_snow = core.get_content_id("st_nodes:surface_snow")
local c_sand = core.get_content_id("st_nodes:surface_sand")
local c_stratum = {}
-- rock content id -> {[mask] = {content ids}}, mask 0 being the rock itself
local c_shaped = {}
for i, s in ipairs(strata) do
	local base = "st_nodes:" .. s.name
	c_stratum[i] = core.get_content_id(base)
	local ids = {[0] = {c_stratum[i]}}
	for mask = 1, shapes.COUNT - 1 do
		ids[mask] = {}
		for n = 1, shapes.VARIANTS do
			ids[mask][n] = core.get_content_id(shapes.variant_name(base, mask, n))
		end
	end
	c_shaped[c_stratum[i]] = ids
end

-- Air and liquids leave a rock side exposed; same rule as st_nodes.refresh_shapes
local is_missing = {[core.get_content_id("air")] = true}
for _, m in ipairs(world.materials) do
	if m.liquid then
		is_missing[core.get_content_id("st_nodes:" .. m.name .. "_source")] = true
	end
end

-- Returns the stratum index at this depth and, inside an overlap, the next one and how
-- far through the overlap the depth is (0 to 1)
local function strata_at(depth)
	local cur = 1
	while strata[cur + 1] and strata[cur + 1].from <= depth do
		cur = cur + 1
	end
	local prev = strata[cur - 1]
	if prev and prev.to and depth < prev.to then
		return cur - 1, cur, (depth - strata[cur].from) / (prev.to - strata[cur].from)
	end
	return cur
end

local place_deposits = dofile(core.get_modpath("st_worldgen") .. "/deposits.lua")(world)

local data = {}
local param2 = {}

core.register_on_generated(function(vm, minp, maxp)
	local z_min = math.max(minp.z, slice_z)
	local z_max = math.min(maxp.z, slice_z + BACK_DEPTH)
	local y_max = math.min(maxp.y, surface_y)
	if z_min > z_max or minp.y > y_max then
		return
	end

	vm:get_data(data)
	vm:get_param2_data(param2)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea(emin, emax)

	-- The slice is generated one node wider than the chunk, so rock on the chunk edge can see
	-- its neighbours; the extra ring is put back as it was before writing
	local px0, px1 = math.max(minp.x - 1, emin.x), math.min(maxp.x + 1, emax.x)
	local py0, py1 = math.max(minp.y - 1, emin.y), math.min(math.min(maxp.y + 1, surface_y), emax.y)

	local size = {x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1}
	local noise_w = size.x + 2
	-- The constructor wants a z even for 2D noise
	local noise = ValueNoiseMap(NOISE_PARAMS, {x = noise_w, y = size.y + 2, z = 1}):get_2d_map_flat(
		{x = minp.x - 1, y = minp.y - 1})

	local rows = {}
	for y = py0, py1 do
		if y == surface_y then
			rows[y] = {c_grass}
		else
			local a, b, t = strata_at(surface_y - y)
			rows[y] = {c_stratum[a], b and c_stratum[b], t}
		end
	end

	local function fill_row(z, xa, xb, ya, yb)
		for y = ya, yb do
			local row = rows[y]
			local id_a, id_b, t = row[1], row[2], row[3]
			local vi = area:index(xa, y, z)
			local ni = (y - (minp.y - 1)) * noise_w + (xa - (minp.x - 1)) + 1
			if y == surface_y then
				for x = xa, xb do
					data[vi] = x < SNOW_X and c_snow or x > DESERT_X and c_sand or c_grass
					vi = vi + 1
				end
			elseif id_b then
				for _ = xa, xb do
					local u = 0.5 + noise[ni] * 0.5
					data[vi] = u < t and id_b or id_a
					vi = vi + 1
					ni = ni + 1
				end
			else
				for _ = xa, xb do
					data[vi] = id_a
					vi = vi + 1
				end
			end
		end
	end

	local ring_vi, ring_id = {}, {}
	for z = z_min, z_max do
		if z == slice_z then
			for y = py0, py1 do
				for x = px0, px1 do
					if x < minp.x or x > maxp.x or y < minp.y or y > y_max then
						local vi = area:index(x, y, z)
						ring_vi[#ring_vi + 1] = vi
						ring_id[#ring_id + 1] = data[vi]
					end
				end
			end
			fill_row(z, px0, px1, py0, py1)
		else
			fill_row(z, minp.x, maxp.x, minp.y, y_max)
			for y = minp.y, y_max do
				local vi = area:index(minp.x, y, z)
				for _ = minp.x, maxp.x do
					param2[vi] = BACK_PARAM2
					vi = vi + 1
				end
			end
		end
	end

	-- Ore, gems and liquids only in the diggable slice; the backing wall stays plain rock
	if z_min == slice_z then
		place_deposits(data, area, {x = px0, y = py0, z = minp.z}, {x = px1, y = py1, z = maxp.z},
			py1, slice_z, slice_z)

		-- Rock picks its shape from the four neighbours in the slice
		local ystride = area.ystride
		for y = minp.y, y_max do
			for x = minp.x, maxp.x do
				local vi = area:index(x, y, slice_z)
				local ids = c_shaped[data[vi]]
				if ids then
					local mask = 0
					if is_missing[data[vi + ystride]] then
						mask = mask + shapes.TOP
					end
					if is_missing[data[vi - ystride]] then
						mask = mask + shapes.BOTTOM
					end
					if is_missing[data[vi - 1]] then
						mask = mask + shapes.LEFT
					end
					if is_missing[data[vi + 1]] then
						mask = mask + shapes.RIGHT
					end
					local options = ids[mask]
					data[vi] = options[shapes.pick(x, y, slice_z, #options)]
				end
			end
		end

		for i = 1, #ring_vi do
			data[ring_vi[i]] = ring_id[i]
		end
	end

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
-- the active pad (a st_pads id, set in init.lua) is the one the machine uses to enter.
local MAIN_X = constants.shop_x
local REFINERY_X = constants.refinery_x
local CONTACT_X = constants.contact_x
local buildings = {}
do
	local function id(name)
		return core.get_content_id(name)
	end
	local function building(x, columns, active_pad)
		for dx, column in ipairs(columns) do
			for dy, part in ipairs(column) do
				buildings[#buildings + 1] = {x + dx - 1, surface_y + dy, id("st_buildings:" .. part), slice_z + 1}
			end
			local pad = active_pad[dx] and "st_pads:pad_" .. active_pad[dx] or "st_pads:pad"
			buildings[#buildings + 1] = {x + dx - 1, surface_y, id(pad)}
		end
	end
	-- Mechanic shop and home: extension, main building with the entrance, annex
	building(MAIN_X - 1, {{"main_ext"}, {"main"}, {"annex"}}, {[2] = "shop"})
	-- Ore refinery: furnace and chimney, hatch and tank
	building(REFINERY_X, {{"refinery_ll", "refinery_ul"}, {"refinery_lr", "refinery_ur"}}, {[2] = "refinery"})
	-- Company contact: office with the entrance, storage to its right
	building(CONTACT_X, {{"contact_office"}, {"contact_storage"}}, {[1] = "contact"})
end
-- Surface decoration, only behind the slice, one node per cell. Trees win over bushes, bushes over
-- grass tufts. Trees and bushes grow in clumps: smooth 2D noise over (x, z), a patch where it is
-- above the first level and denser as it rises. Tufts are scattered evenly. The biome picks the look.
local DECOR_DEPTH = BACK_DEPTH
local TUFT_DENSITY = 0.3
local TUFT_VARIANTS = 3
-- {noise (0..1) above, chance per cell}, low to high
local TREE_LEVELS = {{0.75, 0.04}, {0.83, 0.10}, {0.91, 0.20}}
local BUSH_LEVELS = {{0.75, 0.08}, {0.83, 0.22}, {0.91, 0.45}}
local world_seed = tonumber(core.get_mapgen_setting("seed")) or 0

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
		tufts[biome][v] = core.get_content_id("st_decor:tuft_" .. biome .. "_" .. v)
	end
	for v = 1, 2 do
		bushes[biome][v] = core.get_content_id("st_decor:bush_" .. biome .. "_" .. v)
	end
	local kind = TREE_KIND[biome]
	trees[biome] = {base = core.get_content_id("st_decor:tree_" .. kind .. "_base"), tops = {}}
	for v = 1, TREE_TOPS[kind] do
		trees[biome].tops[v] = core.get_content_id("st_decor:tree_" .. kind .. "_" .. v .. "_top")
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
	local y = surface_y + 1
	local z0, z1 = math.max(minp.z, slice_z + 1), math.min(maxp.z, slice_z + DECOR_DEPTH)
	if y < minp.y or y > maxp.y or z0 > z1 then
		return
	end
	vm:get_data(data)
	vm:get_param2_data(param2)
	local area = VoxelArea(vm:get_emerged_area())
	local size = {x = maxp.x - minp.x + 1, y = z1 - z0 + 1, z = 1}
	local tree_map = ValueNoiseMap(TREE_NOISE, size):get_2d_map_flat({x = minp.x, y = z0})
	local bush_map = ValueNoiseMap(BUSH_NOISE, size):get_2d_map_flat({x = minp.x, y = z0})
	for z = z0, z1 do
		for x = minp.x, maxp.x do
			local ni = (z - z0) * size.x + (x - minp.x) + 1
			local biome = x < SNOW_X and "snow" or x > DESERT_X and "sand" or "grass"
			local i = area:index(x, y, z)
			local free = not (z <= CLEAR_Z_MAX and keep_clear_x[x])
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

-- Debug content in the slice, to look at textures and try things: a row of every ore (poor,
-- regular, rich) on topsoil
local DEBUG_GENERATE = true
local DEBUG_ROW_X, DEBUG_ROW_Y = 20, 2

local debug_nodes = {}
if DEBUG_GENERATE then
	local x = DEBUG_ROW_X
	for _, m in ipairs(world.materials) do
		if not m.liquid then
			for _, richness in ipairs({"poor", "regular", "rich"}) do
				local id = core.get_content_id(world.ore_node(m.name, richness, strata[1].name))
				debug_nodes[#debug_nodes + 1] = {x, DEBUG_ROW_Y, id}
				x = x + 1
			end
			x = x + 1
		end
	end
	core.register_on_generated(make_placer(debug_nodes))
end
