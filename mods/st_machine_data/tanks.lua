-- Data only. An upgrade category: levels[1] is the stock part and is always owned (no from).
-- stats = full stat values while the level is equipped; from = {material = amount} the station consumes to build it.
-- stat = the stat the category is about, with the label and unit the upgrade station shows.
-- A built level is a part the player keeps; one level per category is equipped, and death destroys only that one.
-- Costs: 8 copper plates for the copper tank, x1.25 per level (rounded). Placeholder values, not final.
return {
	id = "tank",
	title = "Fuel tank",
	stat = {key = "max_fuel", label = "Capacity", unit = "L"},
	levels = {
		{name = "stock", description = "Stock tank", stats = {max_fuel = 20}},
		{name = "copper", description = "Copper tank", stats = {max_fuel = 45}, from = {copper_plate = 8}},
		{name = "bronze", description = "Bronze tank", stats = {max_fuel = 75}, from = {bronze = 10}},
		{name = "steel", description = "Steel plate tank", stats = {max_fuel = 110}, from = {steel = 13}},
		{name = "nickel_steel", description = "Nickel steel tank", stats = {max_fuel = 145}, from = {nickel_steel = 16}},
		{name = "titanium", description = "Titanium alloy tank", stats = {max_fuel = 185}, from = {titanium_alloy = 20}},
		{name = "tungsten", description = "Tungsten carbide tank", stats = {max_fuel = 230}, from = {tungsten_carbide = 24}},
		{name = "deep", description = "Deep alloy tank", stats = {max_fuel = 275}, from = {deep_alloy = 31}},
		{name = "platinum", description = "Platinum alloy tank", stats = {max_fuel = 330}, from = {platinum_alloy = 38}},
		{name = "core", description = "Core alloy tank", stats = {max_fuel = 390}, from = {core_alloy = 48}},
	},
}
