-- Data only (also loaded by the mapgen script). curve = {depth in nodes, weight 0..1}, linear between points, 0 outside.
-- density = fraction of nodes that are this material at weight 1 (placeholder values).
return {
	{name = "coal", description = "Coal", shape = "seam", volume = 1, weight = 0.5, density = 0.04, tier = 1, curve = {
		{100, 0.2}, {1000, 1}, {2500, 0.8}, {4600, 0.15}, {9000, 0.05}, {12000, 0},
	}},
	{name = "copper", description = "Copper", shape = "vein", volume = 1, weight = 2.5, density = 0.03, tier = 1, curve = {
		{0, 0.4}, {600, 1}, {1800, 0.8}, {2800, 0.5}, {3200, 0.3}, {8000, 0.1}, {16000, 0.05}, {22000, 0},
	}},
	{name = "tin", description = "Tin", shape = "vein", volume = 1, weight = 2, density = 0.02, tier = 2, curve = {
		{800, 0.1}, {2500, 1}, {3800, 0.6}, {4600, 0.2}, {9000, 0.05}, {12000, 0},
	}},
	{name = "quartz", description = "Quartz", shape = "pocket", volume = 2, weight = 0.3, density = 0.02, tier = 5, curve = {
		{2400, 0.1}, {4500, 1}, {6000, 0.7}, {7500, 0.2}, {14000, 0.1}, {20000, 0.05}, {26000, 0},
	}},
	{name = "iron", description = "Iron ore", shape = "vein", volume = 1, weight = 3, density = 0.04, tier = 3, curve = {
		{2500, 0.05}, {3900, 0.25}, {5500, 1}, {7500, 0.9}, {9000, 0.4}, {12000, 0.15}, {22000, 0.08}, {26000, 0},
	}},
	{name = "aluminum", description = "Aluminum ore", shape = "pocket", volume = 1, weight = 0.4, density = 0.02, tier = 2, curve = {
		{4600, 0.1}, {6500, 1}, {8000, 0.7}, {9000, 0.2}, {14000, 0.08}, {20000, 0},
	}},
	{name = "sulphur", description = "Sulphur", shape = "pocket", volume = 1, weight = 0.8, density = 0.02, tier = 1, curve = {
		{4600, 0.1}, {6500, 0.9}, {9000, 0.5}, {10000, 0.2}, {12500, 0.6}, {15000, 0.1}, {18000, 0},
	}},
	{name = "gold", description = "Gold", shape = "vein", volume = 0.5, weight = 4, density = 0.004, tier = 1, curve = {
		{1500, 0}, {2500, 0.05}, {5000, 0.05}, {7000, 0.15}, {9500, 1}, {12000, 0.4},
		{14000, 0.1}, {20000, 0.05}, {26000, 0},
	}},
	{name = "oil", description = "Oil", shape = "pocket", liquid = true, volume = 1, weight = 0.3, density = 0.003, curve = {
		{7000, 0.1}, {9500, 1}, {12000, 0.7}, {13500, 0.15}, {15000, 0},
	}},
	{name = "lava", description = "Lava", shape = "pocket", liquid = true, volume = 1, weight = 2, density = 0.005, curve = {
		{10500, 0.1}, {13000, 0.5}, {17000, 1}, {20000, 0.8}, {22000, 0.2}, {26000, 0.1}, {31000, 0.1},
	}},
	{name = "core_ore", description = "Core ore", shape = "vein", volume = 1, weight = 2, density = 0.01, tier = 10, curve = {
		{20000, 0.1}, {24000, 0.8}, {28000, 1}, {31000, 1},
	}},
	{name = "graphite", description = "Graphite", shape = "seam", volume = 1, weight = 0.5, density = 0.015, tier = 1, curve = {
		{300, 0.2}, {1500, 1}, {3000, 0.6}, {4600, 0.2}, {8000, 0.15}, {11000, 0.3}, {14000, 0.1}, {17000, 0},
	}},
	{name = "lead", description = "Lead", shape = "vein", volume = 1, weight = 3.5, density = 0.02, tier = 1, curve = {
		{1600, 0.1}, {3500, 1}, {5000, 0.5}, {5500, 0.2}, {9000, 0.08}, {14000, 0},
	}},
	{name = "silver", description = "Silver", shape = "vein", volume = 1, weight = 3, density = 0.006, tier = 2, curve = {
		{4000, 0.1}, {5800, 1}, {7500, 0.4}, {9000, 0.1}, {14000, 0.04}, {18000, 0},
	}},
	{name = "nickel", description = "Nickel", shape = "vein", volume = 1, weight = 2.5, density = 0.012, tier = 4, curve = {
		{5500, 0.1}, {7500, 1}, {9500, 0.7}, {10000, 0.4}, {14000, 0.1}, {20000, 0.04}, {24000, 0},
	}},
	{name = "titanium", description = "Titanium", shape = "vein", volume = 1, weight = 1.2, density = 0.01, tier = 5, curve = {
		{9000, 0.1}, {12000, 1}, {14000, 0.6}, {15000, 0.3}, {20000, 0.1}, {26000, 0.05}, {30000, 0},
	}},
	{name = "tungsten", description = "Tungsten", shape = "vein", volume = 1, weight = 5, density = 0.008, tier = 6, curve = {
		{10000, 0.1}, {13000, 1}, {15000, 0.7}, {16000, 0.4}, {22000, 0.12}, {28000, 0},
	}},
	{name = "platinum", description = "Platinum", shape = "vein", volume = 1, weight = 4, density = 0.003, tier = 3, curve = {
		{12000, 0.1}, {15500, 1}, {17500, 0.6}, {18500, 0.3}, {24000, 0.15}, {30000, 0.08}, {31000, 0.05},
	}},
	{name = "uranium", description = "Uranium", shape = "pocket", volume = 1, weight = 3.5, density = 0.004, tier = 4, curve = {
		{13500, 0.1}, {17000, 1}, {20000, 0.8}, {22000, 0.3}, {26000, 0.2}, {31000, 0.1},
	}},
}
