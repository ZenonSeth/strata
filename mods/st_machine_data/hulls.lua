-- Data only. max_hull = hit points. from = materials needed to build it (smelted, names not final).
-- Placeholder values; the first hull is the one the machine starts with. Built hulls stay owned and can be swapped back to.
return {
	{name = "stock", description = "Stock hull", max_hull = 50, obtainable = false},
	{name = "copper", description = "Copper hull", max_hull = 75, from = {"copper_plate"}},
	{name = "bronze", description = "Bronze hull", max_hull = 115, from = {"bronze"}},
	{name = "steel", description = "Steel plate hull", max_hull = 170, from = {"steel"}},
	{name = "nickel_steel", description = "Nickel steel hull", max_hull = 260, from = {"nickel_steel"}},
	{name = "titanium", description = "Titanium alloy hull", max_hull = 390, from = {"titanium_alloy"}},
	{name = "tungsten", description = "Tungsten carbide hull", max_hull = 590, from = {"tungsten_carbide"}},
	{name = "deep", description = "Deep alloy hull", max_hull = 880, from = {"deep_alloy"}},
	{name = "platinum", description = "Platinum alloy hull", max_hull = 1300, from = {"platinum_alloy"}},
	{name = "core", description = "Core alloy hull", max_hull = 2000, from = {"core_alloy"}},
}
