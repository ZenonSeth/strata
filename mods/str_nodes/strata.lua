-- Data only (also loaded by the mapgen script). from/to = depth in nodes below the surface; neighbours overlap.
return {
	{name = "topsoil",    description = "Topsoil",         from = 0,     to = 1400,  tier = 1},
	{name = "clay",       description = "Clay and gravel", from = 500,   to = 2400,  tier = 2},
	{name = "sandstone",  description = "Sandstone",       from = 1400,  to = 3700,  tier = 3},
	{name = "limestone",  description = "Limestone",       from = 2700,  to = 5200,  tier = 3},
	{name = "shale",      description = "Shale",           from = 4200,  to = 6400,  tier = 4},
	{name = "slate",      description = "Slate",           from = 5400,  to = 7800,  tier = 4},
	{name = "marble",     description = "Marble",          from = 6800,  to = 8800,  tier = 5},
	{name = "schist",     description = "Schist",          from = 7800,  to = 10400, tier = 5},
	{name = "gneiss",     description = "Gneiss",          from = 9400,  to = 12400, tier = 6},
	{name = "basalt",     description = "Basalt",          from = 11400, to = 13900, tier = 6},
	{name = "granite",    description = "Granite",         from = 12900, to = 16500, tier = 7},
	{name = "quartzite",  description = "Quartzite",       from = 15500, to = 17900, tier = 8},
	{name = "eclogite",   description = "Eclogite",        from = 16900, to = 19400, tier = 9},
	{name = "peridotite", description = "Peridotite",      from = 18400, to = 21000, tier = 9},
	{name = "core",       description = "Core rock",       from = 20000, tier = 10},
}
