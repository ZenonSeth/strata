-- Terrain, barrier and liquid stop passes, shared by the mapgen script and the in-place
-- regeneration after a world reset (regen.lua). generate() writes only inside minp..maxp.
local world = dofile(core.get_modpath("str_nodes") .. "/data.lua")
local constants = dofile(core.get_modpath("str_utils") .. "/constants.lua")
local surface_y = constants.surface_y
local slice_z = constants.slice_z
local half_width = constants.world_half_width
local BACK_DEPTH = constants.back_depth
-- param2 that picks the darker palette entry of the rock nodes
local BACK_PARAM2 = 255
-- Surface biome ranges are in constants; the edge between two wanders by up to this many nodes
local BIOME_EDGE_JITTER = 50
local strata = world.strata

-- Picks the rock inside a stratum overlap. Flat in z, so the backing wall continues the slice.
local NOISE_SEED = 7751
local NOISE_PARAMS = {
	offset = 0, scale = 1,
	spread = {x = 300, y = 150 * world.depth_scale, z = 300},
	seed = NOISE_SEED, octaves = 3, persist = 0.5, lacunarity = 2,
}
-- The class does not add the world seed like core.get_value_noise_map would
local strata_seed = (NOISE_SEED + (tonumber(core.get_mapgen_setting("seed")) or 0)) % 2147483647

local world_seed = tonumber(core.get_mapgen_setting("seed")) or 0

-- Seed offset per world reset cycle; only the underground uses it, so the surface never changes
local CYCLE_SALT = 1000003

-- Hills above the surface. The height scales from HILL_SLICE_SCALE in the slice up to full a
-- HILL_RAMP_Z behind it (sine), and rises (sine) from nothing at HILL_FLAT_R around the shop to
-- full at HILL_FULL_R, so the buildings stay on flat ground.
local HILL_MAX = 18
local HILL_SLICE_SCALE = 0.25
local HILL_RAMP_Z = 60
local HILL_FLAT_R, HILL_FULL_R = 45, 120
local HILL_NOISE = {
	offset = 0, scale = 0.8, spread = {x = 80, y = 80, z = 80},
	seed = (3917 + world_seed) % 2147483647, octaves = 2, persist = 0.5, lacunarity = 2,
}
local HILL_TOP = surface_y + HILL_MAX

local EDGE_NOISE = {
	offset = 0, scale = BIOME_EDGE_JITTER * 0.7, spread = {x = 40, y = 40, z = 40},
	seed = (6203 + world_seed) % 2147483647, octaves = 2, persist = 0.5, lacunarity = 2,
}

-- How far each cell of x0..x1, z0..z1 is shifted when looking up its biome; same layout as hill_map
local function edge_map(x0, x1, z0, z1)
	return ValueNoiseMap(EDGE_NOISE, {x = x1 - x0 + 1, y = z1 - z0 + 1, z = 1}):get_2d_map_flat({x = x0, y = z0})
end

local biomes = constants.biomes
local function biome_at(x, shift)
	local bx = x + shift
	for i = 1, #biomes - 1 do
		if bx < biomes[i].x_end then
			return biomes[i].name
		end
	end
	return biomes[#biomes].name
end

-- Hill height (0 or more) per cell of x0..x1, z0..z1 (z >= slice_z), flat, row by z
local function hill_map(x0, x1, z0, z1)
	local w = x1 - x0 + 1
	local noise = ValueNoiseMap(HILL_NOISE, {x = w, y = z1 - z0 + 1, z = 1}):get_2d_map_flat({x = x0, y = z0})
	local heights = {}
	for z = z0, z1 do
		local dz = z - slice_z
		local zf = HILL_SLICE_SCALE + (1 - HILL_SLICE_SCALE) * math.sin(math.pi / 2 * math.min(1, dz / HILL_RAMP_Z))
		for x = x0, x1 do
			local i = (z - z0) * w + (x - x0) + 1
			local d = math.sqrt((x - constants.shop_x) ^ 2 + dz ^ 2)
			local rf = math.sin(math.pi / 2 * math.min(1, math.max(0, (d - HILL_FLAT_R) / (HILL_FULL_R - HILL_FLAT_R))))
			heights[i] = math.floor(HILL_MAX * math.min(1, math.max(0, noise[i])) * zf * rf + 0.5)
		end
	end
	return heights
end

local shapes = dofile(core.get_modpath("str_nodes") .. "/shapes.lua")

local c_grass = core.get_content_id("str_nodes:surface_grass")
local c_snow = core.get_content_id("str_nodes:surface_snow")
local c_sand = core.get_content_id("str_nodes:surface_sand")
local c_grass_back = core.get_content_id("str_nodes:surface_grass_back")
local c_snow_back = core.get_content_id("str_nodes:surface_snow_back")
local c_sand_back = core.get_content_id("str_nodes:surface_sand_back")
local c_surface = {grass = c_grass, snow = c_snow, sand = c_sand}
local c_surface_back = {grass = c_grass_back, snow = c_snow_back, sand = c_sand_back}
local c_stratum = {}
-- rock content id -> {[mask] = {content ids}}, mask 0 being the rock itself
local c_shaped = {}
local function add_shaped(base)
	local id = core.get_content_id(base)
	local ids = {[0] = {id}}
	for mask = 1, shapes.COUNT - 1 do
		ids[mask] = {}
		for n = 1, shapes.VARIANTS do
			ids[mask][n] = core.get_content_id(shapes.variant_name(base, mask, n))
		end
	end
	c_shaped[id] = ids
	return id
end
-- Hot rock ids, shapes included
local is_hot = {}
for i, s in ipairs(strata) do
	c_stratum[i] = add_shaped("str_nodes:" .. s.name)
	if s.hot then
		for _, ids in pairs(c_shaped[add_shaped(world.hot_node(s.name))]) do
			for _, id in ipairs(ids) do
				is_hot[id] = true
			end
		end
	end
end

-- Air and liquids leave a rock side exposed; same rule as str_nodes.refresh_shapes
local is_missing = {[core.get_content_id("air")] = true}
for _, m in ipairs(world.materials) do
	if m.liquid then
		is_missing[core.get_content_id("str_nodes:" .. m.name .. "_source")] = true
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

local place_deposits = dofile(core.get_modpath("str_worldgen") .. "/deposits.lua")(world)
local carve_caverns = dofile(core.get_modpath("str_worldgen") .. "/caverns.lua")(world)
local place_hot_veins = dofile(core.get_modpath("str_worldgen") .. "/hot_veins.lua")(world, constants)

local function terrain(data, param2, area, minp, maxp, salt)
	local z_min = math.max(minp.z, slice_z)
	local z_max = math.min(maxp.z, slice_z + BACK_DEPTH)
	local y_max = math.min(maxp.y, HILL_TOP)
	local x_min = math.max(minp.x, -half_width)
	local x_max = math.min(maxp.x, half_width)
	if z_min > z_max or minp.y > y_max or x_min > x_max then
		return
	end
	NOISE_PARAMS.seed = (strata_seed + salt) % 2147483647
	local emin, emax = area.MinEdge, area.MaxEdge

	-- The slice is generated one node wider than minp..maxp, so rock on the edge can see
	-- its neighbours; the extra ring is put back as it was before returning
	local px0, px1 = math.max(minp.x - 1, emin.x, -half_width), math.min(maxp.x + 1, emax.x, half_width)
	local py0, py1 = math.max(minp.y - 1, emin.y), math.min(math.min(maxp.y + 1, HILL_TOP), emax.y)

	local size = {x = maxp.x - minp.x + 1, y = maxp.y - minp.y + 1, z = maxp.z - minp.z + 1}
	local noise_w = size.x + 2
	-- The constructor wants a z even for 2D noise
	local noise = ValueNoiseMap(NOISE_PARAMS, {x = noise_w, y = size.y + 2, z = 1}):get_2d_map_flat(
		{x = minp.x - 1, y = minp.y - 1})

	local hills = hill_map(minp.x - 1, maxp.x + 1, z_min, z_max)
	local edges = edge_map(minp.x - 1, maxp.x + 1, z_min, z_max)

	local rows = {}
	for y = py0, py1 do
		if y < surface_y then
			local a, b, t = strata_at(surface_y - y)
			rows[y] = {c_stratum[a], b and c_stratum[b], t}
		end
	end

	local function fill_row(z, xa, xb, ya, yb)
		for y = ya, yb do
			local row = rows[y]
			local vi = area:index(xa, y, z)
			local ni = (y - (minp.y - 1)) * noise_w + (xa - (minp.x - 1)) + 1
			if y >= surface_y then
				-- Ground column up to the hill height, the surface node on top, air above
				local hi = (z - z_min) * noise_w + (xa - (minp.x - 1)) + 1
				local ids = (z ~= slice_z and y > surface_y) and c_surface_back or c_surface
				for x = xa, xb do
					local top = surface_y + hills[hi]
					if y == top then
						data[vi] = ids[biome_at(x, edges[hi])]
					elseif y < top then
						data[vi] = c_stratum[1]
					end
					vi = vi + 1
					hi = hi + 1
				end
			elseif row[2] then
				local id_a, id_b, t = row[1], row[2], row[3]
				for _ = xa, xb do
					local u = 0.5 + noise[ni] * 0.5
					data[vi] = u < t and id_b or id_a
					vi = vi + 1
					ni = ni + 1
				end
			else
				for _ = xa, xb do
					data[vi] = row[1]
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
			fill_row(z, x_min, x_max, minp.y, y_max)
			for y = minp.y, y_max do
				local vi = area:index(x_min, y, z)
				for _ = x_min, x_max do
					param2[vi] = BACK_PARAM2
					vi = vi + 1
				end
			end
		end
	end

	-- Caverns reach back into the backing wall; the slice itself is carved after the deposits
	carve_caverns(data, area, x_min, x_max, minp.y, y_max, math.max(z_min, slice_z + 1), z_max, salt)
	place_hot_veins(data, area, x_min, x_max, minp.y, y_max, math.max(z_min, slice_z + 1), z_max, salt)

	-- Ore, gems and liquids only in the diggable slice; the backing wall stays plain rock
	if z_min == slice_z then
		place_deposits(data, area, {x = px0, y = py0, z = minp.z}, {x = px1, y = py1, z = maxp.z},
			py1, slice_z, slice_z, salt)
		carve_caverns(data, area, px0, px1, py0, py1, slice_z, slice_z, salt)
		place_hot_veins(data, area, x_min, x_max, minp.y, y_max, slice_z, slice_z, salt)

		-- Rock picks its shape from the four neighbours in the slice
		local ystride = area.ystride
		for y = minp.y, y_max do
			for x = x_min, x_max do
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
end

-- Invisible walls around the playable box, in the slice only: a column just outside each side
-- edge and a row at the top and bottom limits
local c_barrier = core.get_content_id("str_nodes:barrier")
local barrier_top = surface_y + math.floor(constants.world_height * world.depth_scale + 0.5)
local barrier_bottom = surface_y - math.floor(constants.world_depth * world.depth_scale + 0.5)
local function barrier(data, area, minp, maxp)
	if slice_z < minp.z or slice_z > maxp.z then
		return
	end
	local wall = half_width + 1
	local x0, x1 = math.max(minp.x, -wall), math.min(maxp.x, wall)
	local y0, y1 = math.max(minp.y, barrier_bottom), math.min(maxp.y, barrier_top)
	if x0 > x1 or y0 > y1 then
		return
	end
	for _, x in ipairs({-wall, wall}) do
		if x >= x0 and x <= x1 then
			for y = y0, y1 do
				data[area:index(x, y, slice_z)] = c_barrier
			end
		end
	end
	for _, y in ipairs({barrier_bottom, barrier_top}) do
		if y >= y0 and y <= y1 then
			for x = x0, x1 do
				data[area:index(x, y, slice_z)] = c_barrier
			end
		end
	end
end

-- One layer in front of the slice, under the surface, so liquids stay in the slice. The node at
-- each mapblock's lowest x and y corner carries the reset cycle (mod 256) in param2. In front of
-- hot rock it is the glowing variant, kept after the rock is dug as the backing wall has the vein too.
local c_liquid_stop = core.get_content_id("str_nodes:liquid_stop")
local c_liquid_stop_hot = core.get_content_id("str_nodes:liquid_stop_hot")
local BLOCK = 16
local function liquid_stop(data, param2, area, minp, maxp, mark)
	local z = slice_z - 1
	if z < minp.z or z > maxp.z then
		return
	end
	local x0, x1 = math.max(minp.x, -half_width), math.min(maxp.x, half_width)
	local y1 = math.min(maxp.y, surface_y - 1)
	if x0 > x1 or minp.y > y1 then
		return
	end
	for y = minp.y, y1 do
		local vi = area:index(x0, y, z)
		local corner_row = y % BLOCK == 0
		for x = x0, x1 do
			data[vi] = is_hot[data[vi + area.zstride]] and c_liquid_stop_hot or c_liquid_stop
			param2[vi] = (corner_row and x % BLOCK == 0) and mark or 0
			vi = vi + 1
		end
	end
end

local function generate(data, param2, area, minp, maxp, cycle)
	terrain(data, param2, area, minp, maxp, cycle * CYCLE_SALT % 2147483647)
	barrier(data, area, minp, maxp)
	liquid_stop(data, param2, area, minp, maxp, cycle % 256)
end

return {
	generate = generate,
	hill_map = hill_map,
	edge_map = edge_map,
	biome_at = biome_at,
	HILL_TOP = HILL_TOP,
	BACK_DEPTH = BACK_DEPTH,
	world_seed = world_seed,
}
