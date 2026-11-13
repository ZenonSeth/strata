-- Home furniture

local register_box = st_interior.register_box
local USE = st_utils.constants.interact

-- Two-node pieces: the first node is the one you place and it adds its partner at an offset (turned with the
-- piece's facing for the bed); the partner is hidden from the creative inventory and drops the first node.
-- Digging either one removes the other

local function is_free(pos, player_name)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def and def.buildable_to and not core.is_protected(pos, player_name)
end

-- after_place_node: returns true when the item must be kept because the partner has no room
local function add_partner(pos, placer, partner_name, offset)
	local param2 = core.get_node(pos).param2
	local partner_pos = vector.add(pos, offset)
	local player_name = placer and placer:get_player_name() or ""
	if not is_free(partner_pos, player_name) then
		core.swap_node(pos, {name = "air"}) -- swap: no on_destruct, it could hit another piece's partner
		return true
	end
	core.set_node(partner_pos, {name = partner_name, param2 = param2})
end

-- Removing one half removes the other, which would call back here
local removing = {}

local function remove_partner(pos, partner_name, offset)
	local partner_pos = vector.add(pos, offset)
	if removing[core.hash_node_position(pos)] or core.get_node(partner_pos).name ~= partner_name then
		return
	end
	removing[core.hash_node_position(partner_pos)] = true
	core.remove_node(partner_pos)
	removing[core.hash_node_position(partner_pos)] = nil
end

-- Registers the base node (placeable) and top node of a pair stacked vertically; boxes_* from the generator
local UP = vector.new(0, 1, 0)
local DOWN = vector.new(0, -1, 0)

local function register_stack(name, description, base_boxes, top_boxes)
	local base, top = "st_interior:" .. name .. "_base", "st_interior:" .. name .. "_top"
	register_box(name .. "_base", description, "st_interior_" .. name .. "_base", base_boxes, {
		paramtype2 = "4dir",
		after_place_node = function(pos, placer)
			return add_partner(pos, placer, top, UP)
		end,
		on_destruct = function(pos)
			remove_partner(pos, top, UP)
		end,
	})
	register_box(name .. "_top", description .. " (top)", "st_interior_" .. name .. "_top", top_boxes, {
		paramtype2 = "4dir",
		drop = base,
		groups = {not_in_creative_inventory = 1},
		on_destruct = function(pos)
			remove_partner(pos, base, DOWN)
		end,
	})
end

-- Bed: the head node is the one you place; the foot node is added in front of it (the way the head faces).
-- Either node is the bed: pointing at it shows the sleep prompt
local HEAD = "st_interior:home_bed_head"
local FOOT = "st_interior:home_bed_foot"

local function toward_foot(pos)
	return st_interior.facedir_front[core.get_node(pos).param2 % 4]
end

register_box("home_bed_head", "Bed", "st_interior_home_bed_head", {
	{-13/32, -16/32, 12/32, 13/32, 9/32, 16/32},
	{-14/32, 9/32, 12/32, 14/32, 11/32, 16/32},
	{-13/32, -10/32, -16/32, -10/32, -3/32, 12/32},
	{10/32, -10/32, -16/32, 13/32, -3/32, 12/32},
	{-10/32, -10/32, -16/32, 10/32, -6/32, 12/32},
	{-10/32, -6/32, -16/32, 10/32, 1/32, 12/32},
	{-8/32, 1/32, 1/32, 8/32, 4/32, 11/32},
	{-7/32, 4/32, 2/32, 7/32, 5/32, 10/32},
	{-11/32, 1/32, -16/32, 11/32, 3/32, -2/32},
	{-11/32, -3/32, -16/32, -10/32, 1/32, -2/32},
	{10/32, -3/32, -16/32, 11/32, 1/32, -2/32},
}, {
	-- TODO: sleep feature from todo list
	-- use = USE.sleep,
	pointable = true,
	paramtype2 = "4dir",
	after_place_node = function(pos, placer)
		return add_partner(pos, placer, FOOT, toward_foot(pos))
	end,
	on_destruct = function(pos)
		remove_partner(pos, FOOT, toward_foot(pos))
	end,
})

register_box("home_bed_foot", "Bed (foot)", "st_interior_home_bed_foot", {
	{-13/32, -16/32, -16/32, 13/32, 2/32, -13/32},
	{-14/32, 2/32, -16/32, 14/32, 4/32, -13/32},
	{-13/32, -10/32, -13/32, -10/32, -3/32, 16/32},
	{10/32, -10/32, -13/32, 13/32, -3/32, 16/32},
	{-10/32, -10/32, -13/32, 10/32, -6/32, 16/32},
	{-10/32, -6/32, -13/32, 10/32, 1/32, 16/32},
	{-11/32, 1/32, -13/32, 11/32, 3/32, 16/32},
	{-11/32, -3/32, -13/32, -10/32, 1/32, 16/32},
	{10/32, -3/32, -13/32, 11/32, 1/32, 16/32},
}, {
	-- TODO: sleep feature from todo list
	-- use = USE.sleep,
	pointable = true,
	paramtype2 = "4dir",
	drop = HEAD,
	groups = {not_in_creative_inventory = 1},
	on_destruct = function(pos)
		remove_partner(pos, HEAD, vector.multiply(toward_foot(pos), -1))
	end,
})

-- Nightstand: half a node tall, 28/32 wide, 20/32 deep and flush with the back of the node (against a wall).
-- A drawer over an open shelf. Faces the placer (4dir)
register_box("home_nightstand", "Nightstand", "st_interior_home_nightstand", {
	{-14/32, -2/32, -4/32, 14/32, 0, 16/32},
	{-11/32, -7/32, -3/32, 11/32, -2/32, 16/32},
	{-13/32, -16/32, -3/32, -11/32, -2/32, 16/32},
	{11/32, -16/32, -3/32, 13/32, -2/32, 16/32},
	{-11/32, -16/32, -3/32, 11/32, -12/32, 16/32},
	{-11/32, -12/32, 13/32, 11/32, -7/32, 16/32},
}, {paramtype2 = "4dir"})

-- Bookshelf and wardrobe: 1 wide, 2 tall, flush with the back of the node, decoration only. Place the base, the
-- top is added above it. The bookshelf's books are boxes standing on the boards
register_stack("home_bookshelf", "Bookshelf", {
	{-14/32, -16/32, -4/32, -11/32, 16/32, 16/32},
	{11/32, -16/32, -4/32, 14/32, 16/32, 16/32},
	{-11/32, -16/32, 13/32, 11/32, 16/32, 16/32},
	{-11/32, -16/32, -4/32, 11/32, -13/32, 13/32},
	{-11/32, -1/32, -4/32, 11/32, 1/32, 13/32},
	{-11/32, 14/32, -4/32, 11/32, 16/32, 13/32},
	{-11/32, -13/32, 2/32, -9/32, -5/32, 13/32},
	{-9/32, -13/32, 3/32, -7/32, -6/32, 13/32},
	{-7/32, -13/32, 3/32, -4/32, -2/32, 13/32},
	{-4/32, -13/32, 3/32, -1/32, -6/32, 13/32},
	{-1/32, -13/32, 2/32, 1/32, -5/32, 13/32},
	{6/32, -13/32, 2/32, 8/32, -5/32, 13/32},
	{8/32, -13/32, 2/32, 11/32, -4/32, 13/32},
	{-11/32, 1/32, 3/32, -9/32, 13/32, 13/32},
	{-9/32, 1/32, 3/32, -7/32, 10/32, 13/32},
	{-7/32, 1/32, 2/32, -4/32, 9/32, 13/32},
	{-1/32, 1/32, 2/32, 1/32, 10/32, 13/32},
	{1/32, 1/32, 3/32, 4/32, 12/32, 13/32},
	{4/32, 1/32, 1/32, 6/32, 13/32, 13/32},
	{6/32, 1/32, 1/32, 9/32, 9/32, 13/32},
}, {
	{-14/32, -16/32, -4/32, -11/32, 16/32, 16/32},
	{11/32, -16/32, -4/32, 14/32, 16/32, 16/32},
	{-11/32, -16/32, 13/32, 11/32, 16/32, 16/32},
	{-11/32, -3/32, -4/32, 11/32, -1/32, 13/32},
	{-15/32, 13/32, -5/32, 15/32, 16/32, 16/32},
	{-10/32, -16/32, 2/32, -7/32, -7/32, 13/32},
	{-7/32, -16/32, 2/32, -4/32, -7/32, 13/32},
	{-4/32, -16/32, 1/32, -1/32, -4/32, 13/32},
	{-1/32, -16/32, 2/32, 1/32, -7/32, 13/32},
	{1/32, -16/32, 1/32, 3/32, -6/32, 13/32},
	{3/32, -16/32, 2/32, 5/32, -4/32, 13/32},
	{5/32, -16/32, 2/32, 8/32, -7/32, 13/32},
	{8/32, -16/32, 1/32, 10/32, -5/32, 13/32},
	{-11/32, -1/32, 1/32, -9/32, 12/32, 13/32},
	{-9/32, -1/32, 2/32, -6/32, 9/32, 13/32},
	{-6/32, -1/32, 1/32, -4/32, 9/32, 13/32},
	{-4/32, -1/32, 2/32, -2/32, 10/32, 13/32},
	{2/32, -1/32, 2/32, 4/32, 8/32, 13/32},
	{7/32, -1/32, 1/32, 9/32, 12/32, 13/32},
})

register_stack("home_wardrobe", "Wardrobe", {
	{-12/32, -16/32, -6/32, 12/32, -12/32, 16/32},
	{-14/32, -12/32, -7/32, 14/32, 16/32, 16/32},
	{-13/32, -12/32, -8/32, 0, 16/32, -7/32},
	{0, -12/32, -8/32, 13/32, 16/32, -7/32},
}, {
	{-14/32, -16/32, -7/32, 14/32, 13/32, 16/32},
	{-13/32, -16/32, -8/32, 0, 13/32, -7/32},
	{0, -16/32, -8/32, 13/32, 13/32, -7/32},
	{-15/32, 13/32, -10/32, 15/32, 16/32, 16/32},
})
