-- The manual lying on a surface: a hardcover notebook, closed or open, faces the placer (4dir).
-- Punch toggles open/closed, using it opens the manual window. Not diggable.
local USE = str_utils.constants.interact.manual
local TEXTURE = "str_manual"

local CLOSED_BOXES = {
	{-9/32, -16/32, -12/32, 10/32, -15/32, 12/32},
	{-9/32, -15/32, -11/32, 9/32, -12/32, 11/32},
	{-9/32, -12/32, -12/32, 10/32, -11/32, 12/32},
	{-11/32, -16/32, -12/32, -9/32, -11/32, 12/32},
}

local OPEN_BOXES = {
	{-16/32, -16/32, -12/32, 16/32, -15/32, 12/32},
	{-15/32, -15/32, -11/32, -1/32, -12/32, 11/32},
	{1/32, -15/32, -11/32, 15/32, -12/32, 11/32},
	{-1/32, -15/32, -11/32, 1/32, -14/32, 11/32},
	{-12/32, -12/32, -11/32, -1/32, -11/32, 11/32},
	{1/32, -12/32, -11/32, 12/32, -11/32, 11/32},
}

local function toggle_to(name)
	return function(pos, node)
		core.swap_node(pos, {name = name, param1 = node.param1, param2 = node.param2})
	end
end

local function register(name, description, tiles, boxes, selection, on_punch)
	core.register_node("str_manual:" .. name, {
		description = description,
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "4dir",
		tiles = tiles,
		node_box = {type = "fixed", fixed = boxes},
		selection_box = {type = "fixed", fixed = {selection}},
		walkable = false,
		diggable = false,
		is_ground_content = false,
		use_kind = USE,
		on_rightclick = str_interior.make_on_rightclick(USE),
		on_punch = on_punch,
	})
end

-- top, bottom, +X, -X, +Z, -Z
register("book_closed", "Manual (closed)", {
	TEXTURE .. "_closed_top.png", TEXTURE .. "_bottom.png",
	TEXTURE .. "_closed_side.png", TEXTURE .. "_closed_spine.png",
	TEXTURE .. "_closed_end.png", TEXTURE .. "_closed_end.png",
}, CLOSED_BOXES, {-11/32, -16/32, -12/32, 10/32, -11/32, 12/32}, toggle_to("str_manual:book_open"))

register("book_open", "Manual (open)", {
	TEXTURE .. "_open_top.png", TEXTURE .. "_bottom.png",
	TEXTURE .. "_open_side.png", TEXTURE .. "_open_side.png",
	TEXTURE .. "_open_end.png", TEXTURE .. "_open_end.png",
}, OPEN_BOXES, {-16/32, -16/32, -12/32, 16/32, -11/32, 12/32}, toggle_to("str_manual:book_closed"))

str_interior.register_on_use(USE, function(player_name)
	str_manual.show(player_name)
end)
