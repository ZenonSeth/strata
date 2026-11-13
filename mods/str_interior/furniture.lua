-- Shop furniture: one node tall nodeboxes, facing in param2 (front is the -Z face).

local register_box = str_interior.register_box

-- Cabinet 3/4 node deep, flush with the back, so rows of counters join up
register_box("shop_counter", "Shop counter", "str_interior_shop_counter", {
	{-16/32, 13/32, -9/32, 16/32, 16/32, 16/32},
	{-16/32, -13/32, -8/32, 16/32, 13/32, 16/32},
	{-16/32, -16/32, -5/32, 16/32, -13/32, 16/32},
	{-4/32, 2/32, -10/32, -2/32, 8/32, -8/32},
	{2/32, 2/32, -10/32, 4/32, 8/32, -8/32},
})

-- L of two counter arms: back run along +X, side run toward -Z on the left; the front right is open
register_box("shop_counter_corner", "Shop counter (corner)", "str_interior_shop_counter_corner", {
	{-16/32, 13/32, -9/32, 16/32, 16/32, 16/32},
	{-16/32, 13/32, -16/32, 9/32, 16/32, 16/32},
	{-16/32, -13/32, -8/32, 16/32, 13/32, 16/32},
	{-16/32, -13/32, -16/32, 8/32, 13/32, 16/32},
	{-16/32, -16/32, -5/32, 16/32, -13/32, 16/32},
	{-16/32, -16/32, -16/32, 5/32, -13/32, 16/32},
})

-- Counter with a stainless basin sunk 8/32 into the worktop
register_box("shop_sink", "Shop sink", "str_interior_shop_sink", {
	{-16/32, 13/32, -9/32, 16/32, 16/32, -4/32},
	{-16/32, 13/32, 12/32, 16/32, 16/32, 16/32},
	{-16/32, 13/32, -4/32, -12/32, 16/32, 12/32},
	{12/32, 13/32, -4/32, 16/32, 16/32, 12/32},
	{-16/32, 8/32, -8/32, 16/32, 13/32, -4/32},
	{-16/32, 8/32, 12/32, 16/32, 13/32, 16/32},
	{-16/32, 8/32, -4/32, -12/32, 13/32, 12/32},
	{12/32, 8/32, -4/32, 16/32, 13/32, 12/32},
	{-16/32, -13/32, -8/32, 16/32, 8/32, 16/32},
	{-16/32, -16/32, -5/32, 16/32, -13/32, 16/32},
	{-4/32, -2/32, -10/32, -2/32, 4/32, -8/32},
	{2/32, -2/32, -10/32, 4/32, 4/32, -8/32},
})

-- Goes on the node above the sink, same facing: wall heater, pipe, spout over the basin, tap knobs
register_box("shop_sink_faucet", "Shop sink faucet and heater", "str_interior_shop_sink_faucet", {
	{-6/32, 0, 6/32, 6/32, 14/32, 16/32},
	{-2/32, -16/32, 12/32, 2/32, 0, 16/32},
	{-1/32, -8/32, 3/32, 1/32, -5/32, 14/32},
	{-1/32, -11/32, 3/32, 1/32, -8/32, 5/32},
	{-11/32, -16/32, 13/32, -9/32, -11/32, 15/32},
	{9/32, -16/32, 13/32, 11/32, -11/32, 15/32},
})

-- Workbench halves, placed side by side by hand: a full 1x1 wooden top flat at node height, a hollow
-- steel frame at the outer end of each half
register_box("shop_workbench_l", "Shop workbench (left half)", "str_interior_shop_workbench_l", {
	{-16/32, 12/32, -16/32, 16/32, 16/32, 16/32},
	{-16/32, -16/32, -15/32, -12/32, 12/32, -11/32},
	{-16/32, -16/32, 11/32, -12/32, 12/32, 15/32},
	{-16/32, 8/32, -11/32, -12/32, 12/32, 11/32},
	{-16/32, -16/32, -11/32, -12/32, -12/32, 11/32},
})

register_box("shop_workbench_r", "Shop workbench (right half)", "str_interior_shop_workbench_r", {
	{-16/32, 12/32, -16/32, 16/32, 16/32, 16/32},
	{12/32, -16/32, -15/32, 16/32, 12/32, -11/32},
	{12/32, -16/32, 11/32, 16/32, 12/32, 15/32},
	{12/32, 8/32, -11/32, 16/32, 12/32, 11/32},
	{12/32, -16/32, -11/32, 16/32, -12/32, 11/32},
})

-- Open shelf unit 3/4 deep, flush with the back: steel posts, three boards, boxes and a bin on them
register_box("shop_shelf", "Shop shelf", "str_interior_shop_shelf", {
	{-16/32, -16/32, -8/32, -13/32, 16/32, 16/32},
	{13/32, -16/32, -8/32, 16/32, 16/32, 16/32},
	{-13/32, 13/32, -8/32, 13/32, 16/32, 16/32},
	{-13/32, -2/32, -8/32, 13/32, 1/32, 16/32},
	{-13/32, -16/32, -8/32, 13/32, -13/32, 16/32},
	{-11/32, 1/32, -4/32, -1/32, 10/32, 11/32},
	{0, 1/32, -2/32, 5/32, 6/32, 4/32},
	{6/32, 1/32, -6/32, 12/32, 12/32, 7/32},
	{-12/32, -13/32, -6/32, -2/32, -6/32, 14/32},
	{0, -13/32, -4/32, 12/32, -3/32, 13/32},
})

-- Oil drum: an octagon of three overlapping boxes, 3/4 node wide, with two rib rings
register_box("shop_drum", "Oil drum", "str_interior_shop_drum", {
	{-12/32, -16/32, -6/32, 12/32, 16/32, 6/32},
	{-6/32, -16/32, -12/32, 6/32, 16/32, 12/32},
	{-9/32, -16/32, -9/32, 9/32, 16/32, 9/32},
	{-13/32, 6/32, -7/32, 13/32, 8/32, 7/32},
	{-7/32, 6/32, -13/32, 7/32, 8/32, 13/32},
	{-10/32, 6/32, -10/32, 10/32, 8/32, 10/32},
	{-13/32, -8/32, -7/32, 13/32, -6/32, 7/32},
	{-7/32, -8/32, -13/32, 7/32, -6/32, 13/32},
	{-10/32, -8/32, -10/32, 10/32, -6/32, 10/32},
})

-- Full cube with a pegboard texture on every face; hand tools are placed against it
str_interior.register_node("shop_pegboard", {
	description = "Shop pegboard",
	tiles = {"str_interior_shop_pegboard.png"},
})

-- Upgrade station, 2x2 placed by hand: a steel bench with a cabinet (bottom row), a gantry with a lens
-- over a scan pad and a screen (top row). Any of the four nodes triggers the upgrade listeners
local USE = str_utils.constants.interact

register_box("shop_upgrade_bl", "Upgrade station (bottom left)", "str_interior_shop_upgrade_bl", {
	{-16/32, 12/32, -16/32, 16/32, 16/32, 16/32},
	{-16/32, -16/32, -15/32, -12/32, 12/32, -11/32},
	{-16/32, -16/32, 11/32, -12/32, 12/32, 15/32},
	{-16/32, 8/32, -11/32, -12/32, 12/32, 11/32},
	{-16/32, -16/32, -11/32, -12/32, -12/32, 11/32},
	{-4/32, -16/32, -10/32, 16/32, 12/32, 16/32},
}, {
	use = USE.upgrade,
	-- spans the right half too, so the whole bench is easy to point at
	selection_box = {type = "fixed", fixed = {-16/32, -16/32, -16/32, 48/32, 16/32, 16/32}},
})

register_box("shop_upgrade_br", "Upgrade station (bottom right)", "str_interior_shop_upgrade_br", {
	{-16/32, 12/32, -16/32, 16/32, 16/32, 16/32},
	{12/32, -16/32, -15/32, 16/32, 12/32, -11/32},
	{12/32, -16/32, 11/32, 16/32, 12/32, 15/32},
	{12/32, 8/32, -11/32, 16/32, 12/32, 11/32},
	{12/32, -16/32, -11/32, 16/32, -12/32, 11/32},
	{-16/32, -16/32, -10/32, 4/32, 12/32, 16/32},
}, {use = USE.upgrade})

register_box("shop_upgrade_tl", "Upgrade station (top left)", "str_interior_shop_upgrade_tl", {
	{-10/32, -7/32, 10/32, 16/32, 14/32, 14/32},
	{-2/32, -16/32, 10/32, 2/32, -7/32, 14/32},
	{6/32, -16/32, 2/32, 10/32, 8/32, 6/32},
	{6/32, 5/32, 2/32, 16/32, 8/32, 6/32},
	{12/32, -3/32, 0, 16/32, 5/32, 8/32},
	{13/32, -5/32, 1/32, 16/32, -3/32, 7/32},
	{6/32, -16/32, -2/32, 16/32, -14/32, 10/32},
}, {use = USE.upgrade, light_source = 5})

register_box("shop_upgrade_tr", "Upgrade station (top right)", "str_interior_shop_upgrade_tr", {
	{-16/32, -7/32, 10/32, 10/32, 14/32, 14/32},
	{-2/32, -16/32, 10/32, 2/32, -7/32, 14/32},
	{-10/32, -16/32, 2/32, -6/32, 8/32, 6/32},
	{-16/32, 5/32, 2/32, -6/32, 8/32, 6/32},
	{-16/32, -3/32, 0, -12/32, 5/32, 8/32},
	{-16/32, -5/32, 1/32, -13/32, -3/32, 7/32},
	{-16/32, -16/32, -2/32, -6/32, -14/32, 10/32},
}, {use = USE.upgrade, light_source = 5})

-- Refuel pump, 1 wide and 2 tall placed by hand (base, then top on it): hazard plinth, yellow body, display
-- head and a nozzle on a hose at the right side. Either node triggers the refuel listeners
register_box("shop_refuel_base", "Refuel pump (base)", "str_interior_shop_refuel_base", {
	{-13/32, -16/32, -13/32, 13/32, -12/32, 13/32},
	{-10/32, -12/32, -9/32, 10/32, 16/32, 9/32},
	{11/32, -4/32, -1/32, 13/32, 16/32, 1/32},
	{10/32, -6/32, -1/32, 13/32, -4/32, 1/32},
}, {
	use = USE.refuel,
	-- the whole pump, 2 nodes tall, so the thin top parts are easy to point at
	selection_box = {type = "fixed", fixed = {-14/32, -16/32, -13/32, 14/32, 48/32, 13/32}},
})

register_box("shop_refuel_top", "Refuel pump (top)", "str_interior_shop_refuel_top", {
	{-10/32, -16/32, -9/32, 10/32, 4/32, 9/32},
	{-11/32, 4/32, -10/32, 11/32, 14/32, 10/32},
	{-12/32, 14/32, -11/32, 12/32, 16/32, 11/32},
	{10/32, 1/32, -5/32, 14/32, 3/32, 5/32},
	{11/32, -6/32, -2/32, 14/32, 1/32, 2/32},
	{11/32, -2/32, -8/32, 13/32, 0, -2/32},
	{11/32, -16/32, -1/32, 13/32, -6/32, 1/32},
}, {use = USE.refuel})

-- Repair (welding) station, 1 wide and 2 tall placed by hand (base, then top on it): orange welder with two gas
-- bottles, and a post with an arm, a torch with a glowing tip and a welding mask on top. Either node triggers
-- the repair listeners
register_box("shop_repair_base", "Repair station (base)", "str_interior_shop_repair_base", {
	{-16/32, -16/32, -12/32, 16/32, -12/32, 12/32},
	{-10/32, -12/32, -9/32, 10/32, 8/32, 9/32},
	{-16/32, -12/32, -3/32, -10/32, 10/32, 1/32},
	{-15/32, -12/32, -4/32, -11/32, 10/32, 2/32},
	{-14/32, 10/32, -2/32, -12/32, 13/32, 0},
	{10/32, -12/32, -3/32, 16/32, 10/32, 1/32},
	{11/32, -12/32, -4/32, 15/32, 10/32, 2/32},
	{12/32, 10/32, -2/32, 14/32, 13/32, 0},
	{-9/32, 8/32, 6/32, -5/32, 16/32, 10/32},
	{-3/32, 8/32, 0, 9/32, 10/32, 8/32},
}, {
	use = USE.repair,
	-- the whole station's footprint, 2 nodes tall, so the thin top parts are easy to point at
	selection_box = {type = "fixed", fixed = {-16/32, -16/32, -12/32, 16/32, 48/32, 12/32}},
})

register_box("shop_repair_top", "Repair station (top)", "str_interior_shop_repair_top", {
	{-9/32, -16/32, 6/32, -5/32, 16/32, 10/32},
	{-9/32, 10/32, 6/32, 5/32, 14/32, 10/32},
	{1/32, 8/32, 3/32, 7/32, 15/32, 9/32},
	{2/32, 2/32, 4/32, 6/32, 8/32, 8/32},
	{2/32, -5/32, 4/32, 6/32, 2/32, 8/32},
	{3/32, -12/32, 5/32, 5/32, -5/32, 7/32},
	{3/32, -14/32, 5/32, 5/32, -12/32, 7/32},
	{-8/32, 2/32, 3/32, -6/32, 5/32, 7/32},
	{-10/32, -7/32, 3/32, -4/32, 2/32, 7/32},
}, {use = USE.repair, light_source = 6})

-- Warehouse crates, standing on the floor. The large one fills the middle of its node, a full node tall so crates stack; the small one sits
-- in the back-left corner and turns with the placer (4dir). Either one opens the warehouse
register_box("shop_crate_large", "Warehouse crate (large)", "str_interior_shop_crate_large", {
	{-13/32, -16/32, -13/32, 13/32, 14/32, 13/32},
	{-14/32, 14/32, -14/32, 14/32, 16/32, 14/32},
	{-14/32, -16/32, -14/32, -11/32, 14/32, -11/32},
	{11/32, -16/32, -14/32, 14/32, 14/32, -11/32},
	{-14/32, -16/32, 11/32, -11/32, 14/32, 14/32},
	{11/32, -16/32, 11/32, 14/32, 14/32, 14/32},
}, {use = USE.warehouse})

register_box("shop_crate_small", "Warehouse crate (small)", "str_interior_shop_crate_small", {
	{-13/32, -16/32, 1/32, -1/32, -7/32, 13/32},
	{-14/32, -7/32, 0, 0, -5/32, 14/32},
}, {use = USE.warehouse, paramtype2 = "4dir"})

-- Terminal: keyboard in front of a CRT, on the bottom of its node, faces the placer (4dir). The front tile is
-- a 2-frame strip (blinking cursor), 1 s loop. Opens the messages
local TERMINAL_TEXTURE = "str_interior_shop_terminal"
register_box("shop_terminal", "Terminal", TERMINAL_TEXTURE, {
	{-10/32, -16/32, -13/32, 10/32, -14/32, -5/32},
	{-7/32, -16/32, -3/32, 7/32, -13/32, 10/32},
	{-12/32, -13/32, -4/32, 12/32, 9/32, 2/32},
	{-8/32, -11/32, 2/32, 8/32, 6/32, 13/32},
}, {
	use = USE.terminal,
	paramtype2 = "4dir",
	light_source = 3,
	tiles = {
		TERMINAL_TEXTURE .. "_top.png", TERMINAL_TEXTURE .. "_bottom.png",
		TERMINAL_TEXTURE .. "_left.png", TERMINAL_TEXTURE .. "_right.png",
		TERMINAL_TEXTURE .. "_back.png",
		{name = TERMINAL_TEXTURE .. "_front.png",
			animation = {type = "vertical_frames", aspect_w = 32, aspect_h = 32, length = 1.0}},
	},
})

-- Jar of Luanti jam, decoration: a lid, a label band and the jar, 18/32 wide. Faces the placer (4dir)
local JAM_BOX = {-9/32, -16/32, -9/32, 9/32, 6/32, 9/32}
register_box("decor_jam", "Jar of Luanti jam", "str_interior_decor_jam", {
	{-9/32, -1/32, -9/32, 9/32, 2/32, 9/32},
	{-8/32, 2/32, -8/32, 8/32, 6/32, 8/32},
	{-8/32, -16/32, -8/32, 8/32, -1/32, 8/32},
}, {
	paramtype2 = "4dir",
	selection_box = {type = "fixed", fixed = {JAM_BOX}},
	collision_box = {type = "fixed", fixed = {JAM_BOX}},
})
