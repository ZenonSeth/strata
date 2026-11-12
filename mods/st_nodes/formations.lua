-- Data only (also loaded by the mapgen script). curve as in materials.lua.
-- Rock formations are obstacles: mesh nodes (see tools/gen_rock_mesh.py), one texture per
-- formation in textures/st_nodes_formation_<name>.png.
-- shape: "clump" = small blobs and single pieces, "boulder" = big flat blobs, "vein" = winding lines. rarity = fraction of nodes at weight 1.
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
}
