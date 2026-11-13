-- Data only (also loaded by the mapgen script). curve as in materials.lua.
-- Names, volume, weight and price are in str_materials.
-- rarity = absolute fraction of nodes that are this gem at weight 1 (placeholder values).
return {
	{name = "lapis", tier = 2, shape = "pocket", rarity = 3e-3, curve = {
		{500, 0.2}, {1500, 1}, {3200, 0.8}, {6000, 0.3}, {10000, 0.1}, {16000, 0},
	}},
	{name = "turquoise", tier = 2, shape = "pocket", rarity = 3e-3, curve = {
		{600, 0.2}, {1800, 1}, {4000, 0.8}, {7000, 0.3}, {12000, 0.1}, {18000, 0},
	}},
	{name = "opal", tier = 4, shape = "pocket", rarity = 2e-3, curve = {
		{1600, 0.2}, {3500, 1}, {6000, 0.8}, {9000, 0.3}, {14000, 0.1}, {20000, 0},
	}},
	{name = "jade", tier = 4, shape = "pocket", rarity = 2e-3, curve = {
		{2000, 0.2}, {4500, 1}, {8000, 0.8}, {11000, 0.3}, {16000, 0.1}, {22000, 0},
	}},
	{name = "moonstone", tier = 4, shape = "pocket", rarity = 2e-3, curve = {
		{2500, 0.2}, {5000, 1}, {8000, 0.8}, {11000, 0.3}, {16000, 0.1}, {22000, 0},
	}},
	{name = "amazonite", tier = 4, shape = "pocket", rarity = 2e-3, curve = {
		{2500, 0.2}, {4500, 1}, {8000, 0.8}, {11000, 0.3}, {16000, 0.1}, {22000, 0},
	}},
	{name = "peridot", tier = 5, shape = "pocket", rarity = 1.5e-3, curve = {
		{5000, 0.2}, {7000, 1}, {10000, 0.8}, {13000, 0.3}, {18000, 0.1}, {24000, 0},
	}},
	{name = "garnet", tier = 5, shape = "pocket", rarity = 1.5e-3, curve = {
		{5000, 0.2}, {7500, 1}, {10500, 0.8}, {13500, 0.3}, {18000, 0.1}, {24000, 0},
	}},
	{name = "amethyst", tier = 5, shape = "pocket", rarity = 1.5e-3, curve = {
		{5500, 0.2}, {8000, 1}, {10500, 0.8}, {14000, 0.3}, {19000, 0.1}, {25000, 0},
	}},
	{name = "tourmaline", tier = 5, shape = "pocket", rarity = 1.5e-3, curve = {
		{5500, 0.2}, {8000, 1}, {10500, 0.8}, {14000, 0.3}, {19000, 0.1}, {25000, 0},
	}},
	{name = "aquamarine", tier = 6, shape = "pocket", rarity = 1e-3, curve = {
		{8500, 0.2}, {10500, 1}, {13000, 0.8}, {16000, 0.3}, {20000, 0.1}, {27000, 0},
	}},
	{name = "topaz", tier = 6, shape = "pocket", rarity = 1e-3, curve = {
		{9000, 0.2}, {11000, 1}, {14000, 0.8}, {17000, 0.3}, {21000, 0.1}, {27000, 0},
	}},
	{name = "spinel", tier = 6, shape = "pocket", rarity = 1e-3, curve = {
		{10000, 0.2}, {12500, 1}, {15500, 0.8}, {18000, 0.3}, {22000, 0.1}, {28000, 0},
	}},
	{name = "emerald", tier = 6, shape = "pocket", rarity = 1e-3, curve = {
		{10500, 0.2}, {13000, 1}, {16000, 0.8}, {19000, 0.3}, {23000, 0.1}, {28000, 0},
	}},
	{name = "alexandrite", tier = 6, shape = "pocket", rarity = 1e-3, curve = {
		{11000, 0.2}, {13500, 1}, {16500, 0.8}, {19500, 0.3}, {23000, 0.1}, {29000, 0},
	}},
	{name = "ruby", tier = 4, shape = "pocket", rarity = 6e-4, curve = {
		{5500, 0.2}, {8000, 1}, {12000, 0.8}, {16000, 0.3}, {22000, 0.1}, {28000, 0},
	}},
	{name = "sapphire", tier = 7, shape = "pocket", rarity = 6e-4, curve = {
		{11000, 0.2}, {13000, 1}, {16500, 0.8}, {20000, 0.3}, {25000, 0.1}, {30000, 0},
	}},
	{name = "diamond", tier = 8, shape = "pocket", rarity = 4e-4, curve = {
		{13500, 0.2}, {18000, 1}, {22000, 0.8}, {26000, 0.4}, {31000, 0.2},
	}},
	{name = "dragonstone", tier = 9, shape = "pocket", rarity = 4e-4, curve = {
		{17500, 0.3}, {21000, 0.8}, {25000, 1}, {31000, 0.9},
	}},
	{name = "starstone", tier = 9, shape = "pocket", rarity = 2e-4, curve = {
		{18000, 0.2}, {22000, 1}, {29500, 0.8}, {31000, 0.8},
	}},
	{name = "voidstone", tier = 10, shape = "pocket", rarity = 1e-4, curve = {
		{22000, 0.2}, {27000, 1}, {31000, 1},
	}},
}
