-- Hot rock bands: a pure function of the seed, the reset salt and x, so every chunk agrees
return function(world, constants)
	local HOT = constants.hot_rock
	local surface_y = constants.surface_y
	local floor, max, min = math.floor, math.max, math.min
	local seed = (tonumber(core.get_mapgen_setting("seed")) or 0) % 2147483647
	local START = world.hot_start
	local BOTTOM = floor(constants.world_depth * world.depth_scale + 0.5)
	local MAX_THICK = math.ceil(HOT.thickness[2])
	local PERIOD = HOT.gap_period
	-- Noise rows of neighbouring bands sit this far apart, so their wobbles are unrelated
	local ROW = 1009

	local hot_of = {}
	for _, s in ipairs(world.strata) do
		if s.hot then
			hot_of[core.get_content_id("str_nodes:" .. s.name)] = core.get_content_id(world.hot_node(s.name))
		end
	end

	local function lerp(range, t)
		return range[1] + (range[2] - range[1]) * t
	end

	local function clamp1(v)
		return max(-1, min(1, v))
	end

	-- Bands top down for the current salt: {depth, thickness, seed}
	local bands, noise, cached_salt
	local function prepare(salt)
		if salt == cached_salt then
			return
		end
		cached_salt = salt
		local rng = PcgRandom((seed + salt + 52711) % 2147483647)
		bands = {}
		local depth = START + HOT.spacing[1] * rng:next(300, 1000) / 1000
		while depth < BOTTOM do
			local t = (depth - START) / (BOTTOM - START)
			bands[#bands + 1] = {depth = floor(depth + 0.5), thickness = lerp(HOT.thickness, t),
				seed = rng:next(0, 2147483646)}
			depth = depth + lerp(HOT.spacing, t) * rng:next(750, 1250) / 1000
		end
		noise = ValueNoise({
			offset = 0, scale = 1, spread = {x = HOT.wobble_spread, y = HOT.wobble_spread, z = HOT.wobble_spread},
			seed = (seed + salt + 38867) % 2147483647, octaves = 2, persist = 0.5, lacunarity = 2,
		})
	end

	-- First x of the gap in gap cell j of a band and its length; every cell has one gap
	local function gap_of(band, j)
		local rng = PcgRandom((band.seed + j * 7919) % 2147483647)
		local len = rng:next(HOT.gap_length[1], HOT.gap_length[2])
		return j * PERIOD - band.seed % PERIOD + rng:next(0, PERIOD - len), len
	end

	return function(data, area, x0, x1, y0, y1, z0, z1, salt)
		if x0 > x1 or y0 > y1 or z0 > z1 then
			return
		end
		prepare(salt)
		local zstride = area.zstride
		local dmin, dmax = surface_y - y1, surface_y - y0
		for k, band in ipairs(bands) do
			if band.depth - HOT.wobble <= dmax and band.depth + HOT.wobble + MAX_THICK >= dmin then
				local cell, gap_a, gap_len
				for x = x0, x1 do
					local j = floor((x + band.seed % PERIOD) / PERIOD)
					if j ~= cell then
						cell = j
						gap_a, gap_len = gap_of(band, j)
					end
					if x < gap_a or x >= gap_a + gap_len then
						local wobble = clamp1(noise:get_2d({x = x, y = k * ROW}))
						local vary = clamp1(noise:get_2d({x = x, y = k * ROW + ROW / 2}))
						local thick = max(1, min(MAX_THICK, floor(band.thickness + 0.5 + 0.75 * vary)))
						local top = surface_y - band.depth - floor(HOT.wobble * wobble + 0.5)
						for y = max(top - thick + 1, y0), min(top, y1) do
							local vi = area:index(x, y, z0)
							for _ = z0, z1 do
								local hot = hot_of[data[vi]]
								if hot then
									data[vi] = hot
								end
								vi = vi + zstride
							end
						end
					end
				end
			end
		end
	end
end
