-- Data only. capacity = litres (max_fuel). from = materials needed (smelted, names not final).
-- Placeholder values; the first tank is the one the machine starts with.
return {
	{name = "stock", description = "Stock tank", capacity = 25, obtainable = false},
	{name = "copper", description = "Copper tank", capacity = 100, from = {"copper_plate"}},
	{name = "bronze", description = "Bronze tank", capacity = 150, from = {"bronze"}},
	{name = "iron", description = "Iron plate tank", capacity = 240, from = {"iron_plate"}},
	{name = "nickel_steel", description = "Nickel steel tank", capacity = 360, from = {"nickel_steel"}},
	{name = "titanium", description = "Titanium alloy tank", capacity = 550, from = {"titanium_alloy"}},
	{name = "tungsten", description = "Tungsten carbide tank", capacity = 850, from = {"tungsten_carbide"}},
	{name = "deep", description = "Deep alloy tank", capacity = 1300, from = {"deep_alloy"}},
	{name = "platinum", description = "Platinum alloy tank", capacity = 2000, from = {"platinum_alloy"}},
	{name = "core", description = "Core alloy tank", capacity = 3000, from = {"core_alloy"}},
}
