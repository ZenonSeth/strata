-- Data only (also loaded by the mapgen script). Strange objects join the gems in str_nodes/data.lua, without the gem rarity scale.
-- rarity = absolute fraction of nodes that are this type at weight 1. Each type enters at weight 0.1 at its start depth
-- and follows the shared climb after that; later types start deeper.
return {
	{name = "strange_1", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{11500, 0}, {12000, 0.1}, {15000, 0.3}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_2", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{11500, 0}, {12000, 0.1}, {15000, 0.3}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_3", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{11500, 0}, {12000, 0.1}, {15000, 0.3}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_4", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{13500, 0}, {14000, 0.1}, {15000, 0.3}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_5", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{13500, 0}, {14000, 0.1}, {15000, 0.3}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_6", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{13500, 0}, {14000, 0.1}, {15000, 0.3}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_7", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{16000, 0}, {16500, 0.1}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_8", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{16000, 0}, {16500, 0.1}, {18000, 0.6}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_9", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{18500, 0}, {19000, 0.1}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
	{name = "strange_10", tier = 6, shape = "gem", rarity = 1e-3, relic = true, curve = {
		{18500, 0}, {19000, 0.1}, {21000, 0.85}, {24000, 1}, {30000, 1},
	}},
}
