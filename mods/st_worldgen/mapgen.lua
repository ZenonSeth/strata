-- Terrain exists only at and behind the gameplay slice, up to BACK_DEPTH behind it
local BACK_DEPTH = 100

local world = dofile(core.get_modpath("st_nodes") .. "/data.lua")
local constants = dofile(core.get_modpath("st_utils") .. "/constants.lua")
local surface_y = constants.surface_y
local slice_z = constants.slice_z
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

local c_sand = core.get_content_id("st_nodes:sand")
local c_stratum = {}
for i, s in ipairs(strata) do
	c_stratum[i] = core.get_content_id("st_nodes:" .. s.name)
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

core.register_on_generated(function(vm, minp, maxp)
	local z_min = math.max(minp.z, slice_z)
	local z_max = math.min(maxp.z, slice_z + BACK_DEPTH)
	local y_max = math.min(maxp.y, surface_y)
	if z_min > z_max or minp.y > y_max then
		return
	end

	local size = {x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1}
	-- The constructor wants a z even for 2D noise
	local noise = ValueNoiseMap(NOISE_PARAMS, {x = size.x, y = size.y, z = 1}):get_2d_map_flat({x = minp.x, y = minp.y})

	local rows = {}
	for y = minp.y, y_max do
		if y == surface_y then
			rows[y] = {c_sand}
		else
			local a, b, t = strata_at(surface_y - y)
			rows[y] = {c_stratum[a], b and c_stratum[b], t}
		end
	end

	vm:get_data(data)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea(emin, emax)

	for z = z_min, z_max do
		for y = minp.y, y_max do
			local row = rows[y]
			local id_a, id_b, t = row[1], row[2], row[3]
			local vi = area:index(minp.x, y, z)
			local ni = (y - minp.y) * size.x + 1
			if id_b then
				for _ = minp.x, maxp.x do
					local u = 0.5 + noise[ni] * 0.5
					data[vi] = u < t and id_b or id_a
					vi = vi + 1
					ni = ni + 1
				end
			else
				for _ = minp.x, maxp.x do
					data[vi] = id_a
					vi = vi + 1
				end
			end
		end
	end

	-- Ore, gems and liquids only in the diggable slice; the backing wall stays plain rock
	if z_min == slice_z then
		place_deposits(data, area, minp, maxp, y_max, slice_z, slice_z)
	end

	vm:set_data(data)
	vm:calc_lighting()
end)
