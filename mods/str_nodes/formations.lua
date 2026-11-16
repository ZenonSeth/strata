-- Data only (also loaded by the mapgen script). curve as in materials.lua.
-- Rock formations are obstacles: mesh nodes (see tools/gen_rock_mesh.py), one texture per
-- formation in textures/str_nodes_formation_<name>.png.
-- shape: "clump" = small blobs and single pieces, "boulder" = big flat blobs, "vein" = winding lines,
-- "drop" = 1-2 nodes (an extra entry for an existing formation). rarity = fraction of nodes at weight 1.
return {
	{name = "granite_pluton", description = "Granite pluton", tier = 4, shape = "clump", rarity = 5e-3, curve = {
		{40, 0}, {400, 0.6}, {1500, 1}, {3000, 0.8}, {4500, 0.4}, {5200, 0},
	}},
	{name = "dark_gabbro", description = "Dark gabbro", tier = 6, shape = "clump", rarity = 6e-3, curve = {
		{3000, 0}, {5000, 0.6}, {7500, 1}, {9500, 0.8}, {11500, 0.4}, {13000, 0},
	}},
	{name = "blue_diorite", description = "Blue diorite", tier = 8, shape = "boulder", rarity = 8e-3, curve = {
		{10500, 0}, {12500, 0.6}, {14500, 1}, {16500, 0.8}, {18500, 0.4}, {20000, 0},
	}},
	{name = "obsidian", description = "Obsidian", tier = 10, shape = "vein", rarity = 1e-2, curve = {
		{17000, 0}, {19500, 0.6}, {22000, 1}, {60000, 1}, {60001, 0},
	}},
	-- Scattered drops, each in its formation's depth band, getting more common towards the bottom
	{name = "granite_pluton", shape = "drop", rarity = 1e-3, curve = {
		{5000, 0.3}, {6000, 1}, {7500, 0.5}, {8500, 0},
	}},
	{name = "dark_gabbro", shape = "drop", rarity = 1.5e-3, curve = {
		{5500, 0}, {8000, 0.6}, {11000, 1}, {13500, 0.6}, {15000, 0},
	}},
	{name = "blue_diorite", shape = "drop", rarity = 2.5e-3, curve = {
		{11500, 0}, {14000, 0.6}, {17000, 1}, {20000, 0.6}, {22000, 0},
	}},
	{name = "obsidian", shape = "drop", rarity = 4e-3, curve = {
		{17000, 0}, {20000, 0.3}, {31000, 1},
	}},
}
