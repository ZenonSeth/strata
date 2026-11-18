local STEP = 0.0625
local STEPS = 2
local CELLS = math.floor(1 / STEP + 0.5)
local HALF = 0.5
-- Exposed sides sit this far inside the node so a neighbouring liquid's face does not z-fight them
local EPS = 1 / 256
-- Chance per cell of an extra cube on the dip, and of a lip cell being one step lower
local P_DIP = 0.25
local P_LIP = 0.25
-- Radius in cells of a corner where two exposed sides meet
local RADIUS = 6

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

-- Corner zones: {bit, bit, x side, y side}; a zone is rounded only when both sides are exposed
local CORNERS = {
	{shapes.TOP, shapes.LEFT, -1, 1},
	{shapes.TOP, shapes.RIGHT, 1, 1},
	{shapes.BOTTOM, shapes.LEFT, -1, -1},
	{shapes.BOTTOM, shapes.RIGHT, 1, -1},
}

-- Distance in cells from (x, y) to the exposed outline, negative outside it
local function distance(mask, x, y)
	for _, c in ipairs(CORNERS) do
		if has(mask, c[1]) and has(mask, c[2]) then
			local cx = c[3] < 0 and RADIUS or CELLS - RADIUS
			local cy = c[4] < 0 and RADIUS or CELLS - RADIUS
			if (x - cx) * c[3] > 0 and (y - cy) * c[4] > 0 then
				return RADIUS - math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
			end
		end
	end
	local best = math.huge
	if has(mask, shapes.LEFT) then best = math.min(best, x) end
	if has(mask, shapes.RIGHT) then best = math.min(best, CELLS - x) end
	if has(mask, shapes.BOTTOM) then best = math.min(best, y) end
	if has(mask, shapes.TOP) then best = math.min(best, CELLS - y) end
	return best
end

-- 0 below/left of the node, 1 inside, 2 above/right
local function region(i)
	return i < 0 and 0 or i >= CELLS and 2 or 1
end

-- Front z of the column at cell (i, j), or nil for no column; every column reaches the back.
-- Inside the outline the front is pulled back near it; outside, the back stands out as a lip.
local function column_front(mask, i, j, rand)
	local rx, ry = region(i), region(j)
	if (rx == 0 and not has(mask, shapes.LEFT)) or (rx == 2 and not has(mask, shapes.RIGHT)) or
			(ry == 0 and not has(mask, shapes.BOTTOM)) or (ry == 2 and not has(mask, shapes.TOP)) then
		return nil
	end
	local dist = distance(mask, i + 0.5, j + 0.5)
	if dist >= STEPS then
		return -HALF
	end
	local d = math.floor(dist)
	if d >= 0 then
		local r = STEPS - d
		if rand() < P_DIP then
			r = r - 1
		end
		return -HALF + r * STEP
	end
	local n = STEPS + 1 + d
	if n > 0 and rand() < P_LIP then
		n = n - 1
	end
	return n > 0 and HALF - n * STEP or nil
end

local function build(mask, rand, boxes)
	local LO, HI = -STEPS, CELLS + STEPS - 1
	local front, used = {}, {}
	local function key(i, j)
		return (j - LO) * (HI - LO + 1) + (i - LO)
	end
	for j = LO, HI do
		for i = LO, HI do
			front[key(i, j)] = column_front(mask, i, j, rand)
		end
	end
	local function joins(i, j, z, ri, rj)
		local k = key(i, j)
		return not used[k] and front[k] == z and region(i) == ri and region(j) == rj
	end
	for j = LO, HI do
		for i = LO, HI do
			local z = front[key(i, j)]
			if z and not used[key(i, j)] then
				local ri, rj = region(i), region(j)
				local w = 1
				while i + w <= HI and joins(i + w, j, z, ri, rj) do
					w = w + 1
				end
				local h = 1
				local grow = true
				while grow and j + h <= HI do
					for x = i, i + w - 1 do
						if not joins(x, j + h, z, ri, rj) then
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
						used[key(x, y)] = true
					end
				end
				local x1, y1 = -HALF + i * STEP, -HALF + j * STEP
				local x2, y2 = -HALF + (i + w) * STEP, -HALF + (j + h) * STEP
				-- Inside boxes stop EPS short of an exposed side; outside ones reach EPS in to meet them
				if ri == 0 then
					x2 = x2 + EPS
				elseif ri == 2 then
					x1 = x1 - EPS
				else
					if i == 0 and has(mask, shapes.LEFT) then x1 = x1 + EPS end
					if i + w == CELLS and has(mask, shapes.RIGHT) then x2 = x2 - EPS end
				end
				if rj == 0 then
					y2 = y2 + EPS
				elseif rj == 2 then
					y1 = y1 - EPS
				else
					if j == 0 and has(mask, shapes.BOTTOM) then y1 = y1 + EPS end
					if j + h == CELLS and has(mask, shapes.TOP) then y2 = y2 - EPS end
				end
				boxes[#boxes + 1] = {x1, y1, z, x2, y2, HALF}
			end
		end
	end
end

-- Mask bits mark sides whose neighbour is missing; variant 1..VARIANTS picks one fixed
-- roughening. Returns a fresh list of nodeboxes.
function shapes.boxes(mask, variant)
	local rand = rng(mask * 1009 + variant * 7919 + 12345)
	local boxes = {}
	build(mask, rand, boxes)
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
