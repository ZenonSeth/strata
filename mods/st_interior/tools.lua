-- Flat hand tools: nodeboxes lying on the bottom of their node, placed on any face (floor, wall,
-- ceiling) with all 24 facedir orientations. Shapes and textures from tools/gen_shop_tools.py

local register_box = st_interior.register_box

-- Where a node's up (+Y) points for each facedir axis (param2 / 4)
local AXIS_UP = {
	[0] = {x = 0, y = 1, z = 0}, {x = 0, y = 0, z = 1}, {x = 0, y = 0, z = -1},
	{x = 1, y = 0, z = 0}, {x = -1, y = 0, z = 0}, {x = 0, y = -1, z = 0},
}

-- The same rotations the engine applies to nodeboxes (transformNodeBox in mapnode.cpp)
local function turn(v, degrees, a, b)
	local r = math.rad(degrees)
	local cs, sn = math.cos(r), math.sin(r)
	local w = {x = v.x, y = v.y, z = v.z}
	w[a] = v[a] * cs - v[b] * sn
	w[b] = v[a] * sn + v[b] * cs
	return w
end

local YAW = {[0] = 0, -90, 180, 90}
local AXIS_TURN = {
	[0] = {0, "x", "y"}, {90, "y", "z"}, {-90, "y", "z"}, {-90, "x", "y"}, {90, "x", "y"}, {-180, "x", "y"},
}

local function round_vec(v)
	return {x = math.floor(v.x + 0.5), y = math.floor(v.y + 0.5), z = math.floor(v.z + 0.5)}
end

-- FRONT[param2]: where the node's front (-Z) points
local FRONT = {}
for param2 = 0, 23 do
	local v = turn({x = 0, y = 0, z = -1}, YAW[param2 % 4], "x", "z")
	local t = AXIS_TURN[math.floor(param2 / 4)]
	FRONT[param2] = round_vec(turn(v, t[1], t[2], t[3]))
end
st_interior.facedir_front = FRONT

local function dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

-- The tool lies with its bottom on the clicked face; of the 4 rolls about that face's normal,
-- the one whose front points toward the player (along the face) wins
local function tool_param2(placer, pointed_thing)
	local n = vector.subtract(pointed_thing.above, pointed_thing.under)
	local look = placer:get_look_dir()
	local along = vector.subtract(look, vector.multiply(n, dot(look, n)))
	if n.y == 0 then
		along.y = 0
	end
	local len = vector.length(along)
	local want
	if len >= 0.3 then
		want = vector.multiply(along, -1 / len)
	elseif n.y == 0 then
		want = {x = 0, y = -1, z = 0}
	else
		want = {x = 0, y = 0, z = -1}
	end

	local best, best_score
	for axis = 0, 5 do
		if dot(AXIS_UP[axis], n) == 1 then
			for rot = 0, 3 do
				local param2 = axis * 4 + rot
				local score = dot(FRONT[param2], want)
				if not best_score or score > best_score then
					best, best_score = param2, score
				end
			end
		end
	end
	return best
end

local function place_tool(itemstack, placer, pointed_thing)
	if not placer or pointed_thing.type ~= "node" then
		return itemstack
	end
	return core.item_place(itemstack, placer, pointed_thing, tool_param2(placer, pointed_thing))
end

-- Right-click turns a placed tool 90 degrees about its own up axis
local function turn_tool(pos, node)
	node.param2 = math.floor(node.param2 / 4) * 4 + (node.param2 + 1) % 4
	core.swap_node(pos, node)
end

-- Selection box is a thicker slab than the tool so it is easy to aim at
local SLAB = {-16/32, -16/32, -16/32, 16/32, -10/32, 16/32}

local function register_tool(name, description, boxes)
	register_box(name, description, "st_interior_" .. name, boxes, {
		walkable = false,
		sunlight_propagates = true,
		selection_box = {type = "fixed", fixed = SLAB},
		on_place = place_tool,
		on_rightclick = turn_tool,
	})
end

register_tool("tool_hammer", "Hammer", {
	{-12/32, -16/32, -1/32, 5/32, -13/32, 2/32},
	{5/32, -16/32, -3/32, 11/32, -12/32, 4/32},
	{5/32, -16/32, -6/32, 12/32, -12/32, -3/32},
	{6/32, -16/32, 4/32, 8/32, -12/32, 9/32},
	{9/32, -16/32, 4/32, 11/32, -12/32, 9/32},
})

register_tool("tool_screwdrivers", "Screwdriver set", {
	{-13/32, -16/32, 8/32, -4/32, -13/32, 12/32},
	{-4/32, -16/32, 9/32, 11/32, -14/32, 11/32},
	{-13/32, -16/32, 2/32, -5/32, -13/32, 6/32},
	{-5/32, -16/32, 3/32, 8/32, -14/32, 5/32},
	{-13/32, -16/32, -3/32, -6/32, -13/32, 0},
	{-6/32, -16/32, -2/32, 6/32, -14/32, -1/32},
	{-13/32, -16/32, -9/32, -7/32, -13/32, -6/32},
	{-7/32, -16/32, -8/32, 4/32, -14/32, -7/32},
})

register_tool("tool_drill", "Drill", {
	{-10/32, -16/32, -1/32, 5/32, -12/32, 6/32},
	{5/32, -16/32, 0, 10/32, -13/32, 5/32},
	{10/32, -16/32, 2/32, 15/32, -14/32, 3/32},
	{-7/32, -16/32, -10/32, -2/32, -13/32, -1/32},
	{-8/32, -16/32, -14/32, 0, -13/32, -10/32},
	{-10/32, -16/32, 11/32, 1/32, -14/32, 12/32},
})

register_tool("tool_wrenches", "Wrench set", {
	{-13/32, -16/32, 8/32, 4/32, -14/32, 11/32},
	{4/32, -16/32, 6/32, 6/32, -13/32, 13/32},
	{6/32, -16/32, 11/32, 11/32, -13/32, 13/32},
	{6/32, -16/32, 6/32, 11/32, -13/32, 8/32},
	{-13/32, -16/32, 2/32, 1/32, -14/32, 4/32},
	{1/32, -16/32, 0, 3/32, -13/32, 6/32},
	{3/32, -16/32, 4/32, 7/32, -13/32, 6/32},
	{3/32, -16/32, 0, 7/32, -13/32, 2/32},
	{-13/32, -16/32, -4/32, -2/32, -14/32, -2/32},
	{-2/32, -16/32, -6/32, 0, -13/32, 0},
	{0, -16/32, -2/32, 4/32, -13/32, 0},
	{0, -16/32, -6/32, 4/32, -13/32, -4/32},
	{-13/32, -16/32, -11/32, -5/32, -14/32, -9/32},
	{-5/32, -16/32, -13/32, -3/32, -13/32, -7/32},
	{-3/32, -16/32, -9/32, 0, -13/32, -7/32},
	{-3/32, -16/32, -13/32, 0, -13/32, -11/32},
})

register_tool("tool_pliers", "Pliers", {
	{-13/32, -16/32, 7/32, 1/32, -13/32, 10/32},
	{-13/32, -16/32, 0, 1/32, -13/32, 3/32},
	{1/32, -16/32, 0, 4/32, -13/32, 10/32},
	{4/32, -16/32, 6/32, 12/32, -13/32, 8/32},
	{4/32, -16/32, 2/32, 12/32, -13/32, 4/32},
	{-13/32, -16/32, -8/32, -1/32, -13/32, -5/32},
	{-13/32, -16/32, -14/32, -1/32, -13/32, -11/32},
	{-1/32, -16/32, -14/32, 2/32, -13/32, -5/32},
	{2/32, -16/32, -9/32, 9/32, -13/32, -7/32},
	{2/32, -16/32, -12/32, 9/32, -13/32, -10/32},
})

register_tool("tool_sockets", "Socket set", {
	{-13/32, -16/32, 7/32, 7/32, -14/32, 10/32},
	{7/32, -16/32, 5/32, 12/32, -13/32, 12/32},
	{-13/32, -16/32, -3/32, -8/32, -13/32, 2/32},
	{-7/32, -16/32, -4/32, -1/32, -13/32, 2/32},
	{0, -16/32, -5/32, 7/32, -13/32, 2/32},
	{-13/32, -16/32, -10/32, 5/32, -14/32, -8/32},
	{5/32, -16/32, -11/32, 9/32, -13/32, -7/32},
})

register_tool("tool_saw", "Hand saw", {
	{-14/32, -16/32, 8/32, -6/32, -13/32, 11/32},
	{-14/32, -16/32, -2/32, -6/32, -13/32, 1/32},
	{-14/32, -16/32, 1/32, -12/32, -13/32, 8/32},
	{-8/32, -16/32, 1/32, -6/32, -13/32, 8/32},
	{-6/32, -16/32, -1/32, 3/32, -14/32, 9/32},
	{3/32, -16/32, 0, 9/32, -14/32, 8/32},
	{9/32, -16/32, 2/32, 14/32, -14/32, 6/32},
})

register_tool("tool_parts", "Bolts and nuts", {
	{-12/32, -16/32, 8/32, -9/32, -13/32, 11/32},
	{-9/32, -16/32, 9/32, -3/32, -14/32, 10/32},
	{-1/32, -16/32, 3/32, 2/32, -13/32, 6/32},
	{2/32, -16/32, 4/32, 10/32, -14/32, 5/32},
	{9/32, -16/32, 9/32, 12/32, -13/32, 12/32},
	{10/32, -16/32, 2/32, 11/32, -14/32, 9/32},
	{-10/32, -16/32, -4/32, -6/32, -13/32, 0},
	{-4/32, -16/32, -8/32, 0, -13/32, -4/32},
	{6/32, -16/32, -13/32, 10/32, -13/32, -9/32},
	{4/32, -16/32, -7/32, 9/32, -14/32, -2/32},
	{-12/32, -16/32, -12/32, -9/32, -14/32, -9/32},
})
