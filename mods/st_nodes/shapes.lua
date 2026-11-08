local STEP = 0.0625
local STEPS = 2
local CELLS = math.floor(1 / STEP + 0.5)
local HALF = 0.5
-- Chance per cell of an extra cube on the dip, and of a lip cell being one step lower
local P_DIP = 0.25
local P_LIP = 0.25

local shapes = {
	TOP = 1,
	BOTTOM = 2,
	LEFT = 4,
	RIGHT = 8,
	COUNT = 16,
	-- Rough variants per mask
	VARIANTS = 4,
	FULL = {-HALF, -HALF, -HALF, HALF, HALF, HALF},
}

local function has(mask, bit)
	return mask % (bit * 2) >= bit
end

-- Park-Miller generator in doubles; returns a function giving numbers in [0, 1)
local MODULUS = 2147483647
local function rng(seed)
	local state = seed % MODULUS
	if state == 0 then
		state = 1
	end
	local function next_value()
		state = state * 16807 % MODULUS
		return (state - 1) / (MODULUS - 1)
	end
	for _ = 1, 5 do
		next_value()
	end
	return next_value
end

-- Steps the front face is pulled back at cell (i, j); i counts from the left, j from the bottom
local function recess(mask, i, j)
	local best = 0
	local function consider(bit, d)
		if has(mask, bit) and d < STEPS then
			best = math.max(best, STEPS - d)
		end
	end
	consider(shapes.TOP, CELLS - 1 - j)
	consider(shapes.BOTTOM, j)
	consider(shapes.LEFT, i)
	consider(shapes.RIGHT, CELLS - 1 - i)
	return best
end

local function front_boxes(mask, rand, boxes)
	local rec, used = {}, {}
	for j = 0, CELLS - 1 do
		rec[j] = {}
		for i = 0, CELLS - 1 do
			local r = recess(mask, i, j)
			if r > 0 and rand() < P_DIP then
				r = r - 1
			end
			rec[j][i] = r
		end
	end
	for j = 0, CELLS - 1 do
		for i = 0, CELLS - 1 do
			if not used[j * CELLS + i] then
				local r = rec[j][i]
				local w = 1
				while i + w < CELLS and not used[j * CELLS + i + w] and rec[j][i + w] == r do
					w = w + 1
				end
				local h = 1
				local grow = true
				while grow and j + h < CELLS do
					for x = i, i + w - 1 do
						if used[(j + h) * CELLS + x] or rec[j + h][x] ~= r then
							grow = false
							break
						end
					end
					if grow then
						h = h + 1
					end
				end
				for y = j, j + h - 1 do
					for x = i, i + w - 1 do
						used[y * CELLS + x] = true
					end
				end
				boxes[#boxes + 1] = {
					-HALF + i * STEP, -HALF + j * STEP, -HALF + r * STEP,
					-HALF + (i + w) * STEP, -HALF + (j + h) * STEP, HALF,
				}
			end
		end
	end
end

-- make(a1, a2, raise, z1, z2) builds the box over span a1..a2 along the edge
local EDGES = {
	{bit = shapes.TOP, make = function(a1, a2, r, z1, z2) return {a1, HALF, z1, a2, HALF + r, z2} end},
	{bit = shapes.BOTTOM, make = function(a1, a2, r, z1, z2) return {a1, -HALF - r, z1, a2, -HALF, z2} end},
	{bit = shapes.LEFT, make = function(a1, a2, r, z1, z2) return {-HALF - r, a1, z1, -HALF, a2, z2} end},
	{bit = shapes.RIGHT, make = function(a1, a2, r, z1, z2) return {HALF, a1, z1, HALF + r, a2, z2} end},
}

-- make(raise, z1, z2) builds the corner block where two exposed edges meet
local CORNERS = {
	{shapes.TOP, shapes.LEFT, function(r, z1, z2) return {-HALF - r, HALF, z1, -HALF, HALF + r, z2} end},
	{shapes.TOP, shapes.RIGHT, function(r, z1, z2) return {HALF, HALF, z1, HALF + r, HALF + r, z2} end},
	{shapes.BOTTOM, shapes.LEFT, function(r, z1, z2) return {-HALF - r, -HALF - r, z1, -HALF, -HALF, z2} end},
	{shapes.BOTTOM, shapes.RIGHT, function(r, z1, z2) return {HALF, -HALF - r, z1, HALF + r, -HALF, z2} end},
}

local function lip_edge(edge, rand, boxes)
	local drops = {}
	for c = 0, CELLS - 1 do
		drops[c] = rand() < P_LIP and 1 or 0
	end
	local c = 0
	while c < CELLS do
		local e = c
		while e + 1 < CELLS and drops[e + 1] == drops[c] do
			e = e + 1
		end
		for k = 0, STEPS - 1 do
			local steps = STEPS - k - drops[c]
			if steps > 0 then
				local z2 = HALF - k * STEP
				boxes[#boxes + 1] = edge.make(
					-HALF + c * STEP, -HALF + (e + 1) * STEP, steps * STEP, z2 - STEP, z2)
			end
		end
		c = e + 1
	end
end

-- The back edge of each exposed side stands out past the node, mirroring the front recess
local function lip_boxes(mask, rand, boxes)
	for _, edge in ipairs(EDGES) do
		if has(mask, edge.bit) then
			lip_edge(edge, rand, boxes)
		end
	end
	for _, corner in ipairs(CORNERS) do
		if has(mask, corner[1]) and has(mask, corner[2]) then
			local drop = rand() < P_LIP and 1 or 0
			for k = 0, STEPS - 1 do
				local steps = STEPS - k - drop
				if steps > 0 then
					local z2 = HALF - k * STEP
					boxes[#boxes + 1] = corner[3](steps * STEP, z2 - STEP, z2)
				end
			end
		end
	end
end

-- Mask bits mark sides whose neighbour is missing; variant 1..VARIANTS picks one fixed
-- roughening. Returns a fresh list of nodeboxes.
function shapes.boxes(mask, variant)
	local rand = rng(mask * 1009 + variant * 7919 + 12345)
	local boxes = {}
	front_boxes(mask, rand, boxes)
	lip_boxes(mask, rand, boxes)
	return boxes
end

function shapes.variant_name(base, mask, variant)
	return base .. "__e" .. mask .. "_" .. variant
end

-- Stable variant 1..n for a node position
function shapes.pick(x, y, z, n)
	local rand = rng(x * 73856093 + y * 19349663 + z * 83492791)
	return math.floor(rand() * n) + 1
end

return shapes
