-- Terrain exists only for z >= 0 (the gameplay slice is z = 0), up to BACK_DEPTH
local BACK_DEPTH = 100
-- Nodes of depth per dirt level, and how many levels the noise can shift it
local LEVEL_STEP = 30
local LEVEL_JITTER = 1.5

local NOISE_SEED = 7751
local NOISE_PARAMS = {
	offset = 0, scale = 1,
	spread = {x = 24, y = 24, z = 24},
	seed = NOISE_SEED, octaves = 2, persist = 0.5, lacunarity = 2,
}
-- The class does not add the world seed like core.get_value_noise_map would
NOISE_PARAMS.seed = (NOISE_SEED + (tonumber(core.get_mapgen_setting("seed")) or 0)) % 2147483647

local c_sand = core.get_content_id("st_nodes:sand")
local c_dirt = {}
while core.registered_nodes["st_nodes:dirt_" .. (#c_dirt + 1)] do
	c_dirt[#c_dirt + 1] = core.get_content_id("st_nodes:dirt_" .. (#c_dirt + 1))
end

local data = {}

core.register_on_generated(function(vm, minp, maxp)
	local z_min = math.max(minp.z, 0)
	local z_max = math.min(maxp.z, BACK_DEPTH)
	local y_max = math.min(maxp.y, -1)
	if z_min > z_max or minp.y > y_max then
		return
	end

	local size = {x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1}
	local noise = ValueNoiseMap(NOISE_PARAMS, size):get_3d_map_flat(minp)

	vm:get_data(data)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea(emin, emax)

	for z = z_min, z_max do
		for y = minp.y, y_max do
			local vi = area:index(minp.x, y, z)
			local ni = ((z - minp.z) * size.y + (y - minp.y)) * size.x + 1
			for _ = minp.x, maxp.x do
				if y == -1 then
					data[vi] = c_sand
				else
					local level = math.floor((-y - 2) / LEVEL_STEP + noise[ni] * LEVEL_JITTER) + 1
					data[vi] = c_dirt[math.max(1, math.min(#c_dirt, level))]
				end
				vi = vi + 1
				ni = ni + 1
			end
		end
	end

	vm:set_data(data)
	vm:calc_lighting()
end)
