-- Carves caverns out of rock, ore, gems and formations (liquids are left alone).
-- Cavern origins are picked per 2D cell on the slice and every cavern is a pure function of its
-- cell, so it is identical in every chunk that touches it.
return function(world)
	local constants = dofile(core.get_modpath("str_utils") .. "/constants.lua")
	local surface_y, slice_z = constants.surface_y, constants.slice_z
	local cfg = world.caverns
	local CELL = 64
	-- Mean slice cross-section for the size distribution below
	local AVG_AREA = 260
	local MARGIN = math.ceil(cfg.max_radius)
	local floor, ceil, sin = math.floor, math.ceil, math.sin
	local seed = (tonumber(core.get_mapgen_setting("seed")) or 0) % 2147483647
	local air = core.get_content_id("air")

	local carvable = {}
	for _, s in ipairs(world.strata) do
		carvable[core.get_content_id("str_nodes:" .. s.name)] = true
		for _, g in ipairs(world.gems) do
			carvable[core.get_content_id(world.gem_node(g.name, s.name))] = true
		end
		for _, m in ipairs(world.materials) do
			if not m.liquid then
				for _, richness in ipairs({"poor", "regular", "rich"}) do
					carvable[core.get_content_id(world.ore_node(m.name, richness, s.name))] = true
				end
			end
		end
	end
	for _, f in ipairs(world.formations) do
		for n = 1, world.formation_variants do
			carvable[core.get_content_id(world.formation_node(f.name, n))] = true
		end
	end

	local function weight_at(depth)
		local curve = cfg.curve
		local n = #curve
		if depth < curve[1][1] or depth > curve[n][1] then
			return 0
		end
		for i = 2, n do
			local a, b = curve[i - 1], curve[i]
			if depth <= b[1] then
				if b[1] == a[1] then
					return b[2]
				end
				return a[2] + (b[2] - a[2]) * (depth - a[1]) / (b[1] - a[1])
			end
		end
		return curve[n][2]
	end

	local function carve(data, area, x0, x1, y0, y1, z0, z1, ox, oy, rx, ry, rz, dseed)
		local ix, iy = ceil(rx), ceil(ry)
		local zlo, zhi = math.max(z0, slice_z), math.min(z1, slice_z + ceil(rz))
		for z = zlo, zhi do
			local dz = (z - slice_z) / rz
			for y = math.max(y0, oy - iy), math.min(y1, oy + iy) do
				local dy = (y - oy) / ry
				for x = math.max(x0, ox - ix), math.min(x1, ox + ix) do
					local d2 = ((x - ox) / rx) ^ 2 + dy * dy + dz * dz
					if d2 < 1 then
						-- Ragged edge: the same hash whatever chunk is being generated
						local h = sin(x * 12.9898 + y * 78.233 + z * 37.719 + dseed) * 43758.5453
						if d2 < 0.7 or h - floor(h) < 0.5 then
							local vi = area:index(x, y, z)
							if carvable[data[vi]] then
								data[vi] = air
							end
						end
					end
				end
			end
		end
	end

	-- Carves into data inside x0..x1, y0..y1, z0..z1 (must lie inside the emerged area)
	return function(data, area, x0, x1, y0, y1, z0, z1)
		if z1 < slice_z then
			return
		end
		local expected = CELL * CELL * cfg.rarity / AVG_AREA
		for cy = floor((y0 - MARGIN) / CELL), floor((y1 + MARGIN) / CELL) do
			for cx = floor((x0 - MARGIN) / CELL), floor((x1 + MARGIN) / CELL) do
				local rng = PcgRandom((cx * 73856093 + cy * 19349663 + 4256233 + seed) % 2147483647)
				local count = floor(expected)
				if rng:next(0, 9999) / 10000 < expected - count then
					count = count + 1
				end
				for _ = 1, count do
					local ox = cx * CELL + rng:next(0, CELL - 1)
					local oy = cy * CELL + rng:next(0, CELL - 1)
					local accept = rng:next(0, 9999) / 10000 < weight_at(surface_y - oy)
					local u1, u2, u3 = rng:next(0, 1000) / 1000, rng:next(5, 10) / 10, rng:next(0, 1000) / 1000
					local swap = rng:next(0, 1) == 1
					local dseed = rng:next(0, 1000000)
					if accept then
						local rx = cfg.min_radius + (cfg.max_radius - cfg.min_radius) * u1 * u1
						local ry = rx * u2
						if swap then
							rx, ry = ry, rx
						end
						local rz = cfg.min_depth + (cfg.max_depth - cfg.min_depth) * u3 * u3
						carve(data, area, x0, x1, y0, y1, z0, z1, ox, oy, rx, ry, rz, dseed)
					end
				end
			end
		end
	end
end
