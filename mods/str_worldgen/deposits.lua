-- Places ore, gems and liquids into rock the strata pass has already written.
-- Deposits are generated per cell from the cell position, so they are identical in every
-- chunk that touches them and continue across chunk borders.
return function(world)
	local surface_y = dofile(core.get_modpath("str_utils") .. "/constants.lua").surface_y
	local CELL = 16
	-- Linear size multiplier for pockets, lakes, veins and seams (gems stay tiny)
	local SIZE = 1.5
	local JITTER = 0.15
	local POOR_BELOW, REGULAR_BELOW = 0.25, 0.6

	local seed = (tonumber(core.get_mapgen_setting("seed")) or 0) % 2147483647

	-- Rough node counts per deposit, used to turn density into a number of deposits
	local floor, ceil, sin, sqrt = math.floor, math.ceil, math.sin, math.sqrt
	local AVG_SIZE = {
		pocket = 50 * SIZE ^ 3, vein = 33 * SIZE, seam = 150 * SIZE ^ 2, gem = 2.5, lake = 250 * SIZE ^ 3,
		clump = 5, boulder = 100,
	}
	local REACH = {
		pocket = ceil(5 * SIZE), vein = ceil(22 * SIZE), seam = ceil(16 * SIZE), gem = 4, lake = ceil(10 * SIZE),
		clump = 2, boulder = 7,
	}
	-- Must cover the biggest reach of any deposit shape
	local MARGIN = 0
	for _, r in pairs(REACH) do
		MARGIN = math.max(MARGIN, r)
	end

	local function id(name)
		return core.get_content_id("str_nodes:" .. name)
	end

	local RICHNESS = {"poor", "regular", "rich"}

	local is_rock = {}
	local is_rock_or_ore = {}
	-- Rock or ore content id -> the rock it sits in; ore and gem nodes exist per host rock
	local host_of = {}
	for _, s in ipairs(world.strata) do
		local rock = id(s.name)
		is_rock[rock] = true
		is_rock_or_ore[rock] = true
		host_of[rock] = rock
	end

	-- Formations first (ore and gems only replace plain rock), then ores and liquids, gems last
	-- (a gem may replace ore)
	local kinds = {}
	for _, f in ipairs(world.formations) do
		local ids = {}
		for n = 1, world.formation_variants do
			ids[n] = core.get_content_id(world.formation_node(f.name, n))
		end
		kinds[#kinds + 1] = {
			curve = f.curve, density = f.rarity, shape = f.shape, avg = AVG_SIZE[f.shape],
			ids = ids, variants = true, replace = is_rock,
		}
	end
	for _, m in ipairs(world.materials) do
		local kind = {curve = m.curve, density = m.density}
		if m.liquid then
			kind.shape = "lake"
			kind.ids = {id(m.name .. "_source")}
			kind.replace = is_rock
		else
			kind.shape = m.shape
			kind.by_host = {}
			kind.replace = is_rock
			for _, s in ipairs(world.strata) do
				local rock = id(s.name)
				local ids = {}
				for n, richness in ipairs(RICHNESS) do
					ids[n] = core.get_content_id(world.ore_node(m.name, richness, s.name))
					is_rock_or_ore[ids[n]] = true
					host_of[ids[n]] = rock
				end
				kind.by_host[rock] = ids
			end
		end
		kind.avg = AVG_SIZE[kind.shape]
		kinds[#kinds + 1] = kind
	end
	for _, g in ipairs(world.gems) do
		local by_host = {}
		for _, s in ipairs(world.strata) do
			by_host[id(s.name)] = {core.get_content_id(world.gem_node(g.name, s.name))}
		end
		kinds[#kinds + 1] = {
			curve = g.curve, density = g.rarity, shape = "gem", avg = AVG_SIZE.gem,
			by_host = by_host, replace = is_rock_or_ore,
		}
	end

	local function weight_at(curve, depth)
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

	local function round(v)
		return floor(v + 0.5)
	end

	-- Each shape calls put(x, y, z) for the nodes it covers, around its origin
	local function blob(rng, ox, oy, oz, put, rx, ry, rz, fuzz)
		local ix, iy, iz = ceil(rx), ceil(ry), ceil(rz)
		for dz = -iz, iz do
			for dy = -iy, iy do
				for dx = -ix, ix do
					local d2 = (dx / rx) ^ 2 + (dy / ry) ^ 2 + (dz / rz) ^ 2
					if d2 < 0.7 or (d2 < 1 and (not fuzz or rng:next(0, 1) == 1)) then
						put(ox + dx, oy + dy, oz + dz)
					end
				end
			end
		end
	end

	local shapes = {}

	function shapes.pocket(rng, ox, oy, oz, put)
		local rx = rng:next(15, 35) / 10 * SIZE
		blob(rng, ox, oy, oz, put, rx, rx * rng:next(6, 10) / 10, rx * rng:next(6, 10) / 10, true)
	end

	function shapes.lake(rng, ox, oy, oz, put)
		blob(rng, ox, oy, oz, put, rng:next(30, 80) / 10 * SIZE, rng:next(15, 35) / 10 * SIZE, rng:next(30, 60) / 10 * SIZE, false)
	end

	function shapes.gem(rng, ox, oy, oz, put)
		put(ox, oy, oz)
		for _ = 1, rng:next(0, 3) do
			ox, oy, oz = ox + rng:next(-1, 1), oy + rng:next(-1, 1), oz + rng:next(-1, 1)
			put(ox, oy, oz)
		end
	end

	-- Small blobs and lone pieces
	function shapes.clump(rng, ox, oy, oz, put)
		if rng:next(0, 99) < 60 then
			put(ox, oy, oz)
			if rng:next(0, 3) == 0 then
				put(ox + rng:next(-1, 1), oy + rng:next(-1, 1), oz)
			end
			return
		end
		local r = rng:next(10, 20) / 10
		blob(rng, ox, oy, oz, put, r, r * rng:next(6, 10) / 10, r * rng:next(6, 10) / 10, true)
	end

	-- Big flat blobs, wider than tall
	function shapes.boulder(rng, ox, oy, oz, put)
		local r = rng:next(30, 65) / 10
		blob(rng, ox, oy, oz, put, r, r * rng:next(30, 50) / 100, r * rng:next(6, 10) / 10, true)
	end

	function shapes.vein(rng, ox, oy, oz, put)
		local len = round(rng:next(15, 35) * SIZE)
		local dx, dy, dz = rng:next(-100, 100) / 100, rng:next(-60, 60) / 100, rng:next(-100, 100) / 100
		local norm = sqrt(dx * dx + dy * dy + dz * dz)
		if norm < 0.1 then
			dx, dy, dz, norm = 1, 0, 0, 1
		end
		dx, dy, dz = dx / norm, dy / norm, dz / norm
		local x, y, z = ox - dx * len / 2, oy - dy * len / 2, oz - dz * len / 2
		for _ = 1, len do
			local px, py, pz = round(x), round(y), round(z)
			put(px, py, pz)
			if rng:next(0, 2) == 0 then
				local axis = rng:next(1, 3)
				put(px + (axis == 1 and 1 or 0), py + (axis == 2 and 1 or 0), pz + (axis == 3 and 1 or 0))
			end
			dx, dy, dz = dx + rng:next(-30, 30) / 100, dy + rng:next(-20, 20) / 100, dz + rng:next(-30, 30) / 100
			norm = sqrt(dx * dx + dy * dy + dz * dz)
			if norm < 0.1 then
				dx, dy, dz, norm = 1, 0, 0, 1
			end
			dx, dy, dz = dx / norm, dy / norm, dz / norm
			x, y, z = x + dx, y + dy, z + dz
		end
	end

	function shapes.seam(rng, ox, oy, oz, put)
		local ax, az = rng:next(50, 120) / 10 * SIZE, rng:next(30, 60) / 10 * SIZE
		local thick = rng:next(1, 2)
		local phase = rng:next(0, 628) / 100
		for dz = -ceil(az), ceil(az) do
			for dx = -ceil(ax), ceil(ax) do
				if (dx / ax) ^ 2 + (dz / az) ^ 2 < 1 then
					local y = oy + round(sin(dx * 0.4 + phase) * 0.8)
					for t = 0, thick - 1 do
						put(ox + dx, y + t, oz + dz)
					end
				end
			end
		end
	end

	-- Called with the chunk's buffer after the strata are written
	return function(data, area, minp, maxp, y_max, z_min, z_max)
		local kind, jitter
		local function put(x, y, z)
			if x < minp.x or x > maxp.x or y < minp.y or y > y_max or z < z_min or z > z_max then
				return
			end
			local vi = area:index(x, y, z)
			local current = data[vi]
			if not kind.replace[current] then
				return
			end
			if kind.variants then
				local pick = PcgRandom((x * 73856093 + y * 19349663 + z * 83492791) % 2147483647)
				data[vi] = kind.ids[pick:next(1, #kind.ids)]
				return
			end
			local ids = kind.ids or kind.by_host[host_of[current]]
			if #ids == 1 then
				data[vi] = ids[1]
				return
			end
			local w = weight_at(kind.curve, surface_y - y) + jitter
			data[vi] = ids[w < POOR_BELOW and 1 or (w < REGULAR_BELOW and 2 or 3)]
		end

		local weights = {}
		local cx0, cx1 = floor((minp.x - MARGIN) / CELL), floor((maxp.x + MARGIN) / CELL)
		local cy0, cy1 = floor((minp.y - MARGIN) / CELL), floor((y_max + MARGIN) / CELL)
		local cz0, cz1 = floor((z_min - MARGIN) / CELL), floor((z_max + MARGIN) / CELL)

		for cy = cy0, cy1 do
			local depth = surface_y - (cy * CELL + CELL / 2)
			local row = {}
			local any = false
			for k, kd in ipairs(kinds) do
				row[k] = weight_at(kd.curve, depth)
				any = any or row[k] > 0
			end
			weights[cy] = any and row
		end

		for cy = cy0, cy1 do
			local row = weights[cy]
			if row then
				for cz = cz0, cz1 do
					for cx = cx0, cx1 do
						local rng = PcgRandom((cx * 73856093 + cy * 19349663 + cz * 83492791 + seed) % 2147483647)
						for k, kd in ipairs(kinds) do
							local w = row[k]
							if w > 0 then
								local expected = CELL * CELL * CELL * kd.density * w / kd.avg
								local count = floor(expected)
								if rng:next(0, 9999) / 10000 < expected - count then
									count = count + 1
								end
								for _ = 1, count do
									local ox = cx * CELL + rng:next(0, CELL - 1)
									local oy = cy * CELL + rng:next(0, CELL - 1)
									local oz = cz * CELL + rng:next(0, CELL - 1)
									local dseed = rng:next(0, 1073741823)
									local jit = rng:next(-1000, 1000) / 1000 * JITTER
									local reach = REACH[kd.shape]
									if ox + reach >= minp.x and ox - reach <= maxp.x
											and oy + reach >= minp.y and oy - reach <= y_max
											and oz + reach >= z_min and oz - reach <= z_max then
										kind, jitter = kd, jit
										shapes[kd.shape](PcgRandom(dseed), ox, oy, oz, put)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end
