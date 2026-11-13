-- Shapes and textures come from art/building_*.nbx (nodebox editor); one node per part
local function register(name, description, texture, boxes)
	core.register_node("str_buildings:" .. name, {
		description = description,
		drawtype = "nodebox",
		paramtype = "light",
		tiles = {
			texture .. "_top.png", texture .. "_bottom.png",
			texture .. "_left.png", texture .. "_right.png",
			texture .. "_back.png", texture .. "_front.png",
		},
		node_box = {type = "fixed", fixed = boxes},
		diggable = false,
		is_ground_content = false,
		groups = {not_in_creative_inventory = 1},
	})
end

register("main", "Building (main)", "str_buildings_main", {
	{-16/32, 9/32, -16/32, 16/32, 16/32, -10/32},
	{-16/32, -16/32, -16/32, -13/32, 9/32, -10/32},
	{13/32, -16/32, -16/32, 16/32, 9/32, -10/32},
	{-16/32, -16/32, -10/32, 16/32, 16/32, 16/32},
})

register("annex", "Building (annex)", "str_buildings_annex", {
	{-16/32, -2/32, -12/32, 16/32, 0, 16/32},
	{-16/32, -16/32, -8/32, 16/32, -2/32, 16/32},
})

register("main_ext", "Building (main, extension)", "str_buildings_main_ext", {
	{-16/32, 9/32, -16/32, 16/32, 16/32, 16/32},
	{-16/32, -16/32, -13/32, 16/32, 9/32, 16/32},
	{-13/32, -7/32, -15/32, -1/32, -5/32, -13/32},
	{1/32, -7/32, -15/32, 13/32, -5/32, -13/32},
})

-- Ore refinery, 2x2 nodes: furnace and hatch below, chimney and tank above
register("refinery_ll", "Refinery (furnace)", "str_buildings_refinery_ll", {
	{-16/32, -6/32, -16/32, 16/32, 16/32, 16/32},
	{-16/32, -16/32, -16/32, -8/32, -6/32, 16/32},
	{8/32, -16/32, -16/32, 16/32, -6/32, 16/32},
	{-8/32, -16/32, -8/32, 8/32, -6/32, 16/32},
})

register("refinery_lr", "Refinery (hatch)", "str_buildings_refinery_lr", {
	{-16/32, 12/32, -13/32, 16/32, 16/32, 16/32},
	{-16/32, -16/32, -13/32, 16/32, 12/32, 16/32},
	{-16/32, 6/32, -16/32, 14/32, 10/32, -13/32},
	{10/32, 6/32, -16/32, 14/32, 16/32, -13/32},
	{-4/32, 5/32, -16/32, -2/32, 11/32, -12/32},
})

register("refinery_ul", "Refinery (chimney)", "str_buildings_refinery_ul", {
	{-9/32, 10/32, -9/32, 9/32, 16/32, 9/32},
	{-6/32, -8/32, -6/32, 6/32, 10/32, 6/32},
	{-10/32, -16/32, -10/32, 10/32, -8/32, 10/32},
})

register("refinery_ur", "Refinery (tank)", "str_buildings_refinery_ur", {
	{-13/32, -16/32, -10/32, 4/32, 1/32, 9/32},
	{-7/32, 1/32, -5/32, -3/32, 6/32, -1/32},
	{10/32, -16/32, -16/32, 14/32, 4/32, -13/32},
	{9/32, 2/32, -16/32, 15/32, 4/32, -12/32},
})

-- Company contact: light bank-like office facade (3/4 node) next to a red-brick storage
register("contact_office", "Company shop (office)", "str_buildings_contact_office", {
	{-16/32, 2/32, -16/32, 16/32, 8/32, 16/32},
	{-16/32, -16/32, -14/32, 16/32, 2/32, 16/32},
	{-14/32, -15/32, -16/32, -6/32, -13/32, -14/32},
	{6/32, -15/32, -16/32, 14/32, -13/32, -14/32},
})

register("contact_storage", "Company shop (storage)", "str_buildings_contact_storage", {
	{-16/32, 10/32, -16/32, 16/32, 14/32, 16/32},
	{-16/32, -16/32, -13/32, 16/32, 10/32, 16/32},
	{-16/32, -16/32, -16/32, -12/32, 10/32, -13/32},
	{12/32, -16/32, -16/32, 16/32, 10/32, -13/32},
	{-4/32, 5/32, -15/32, 3/32, 8/32, -13/32},
})
