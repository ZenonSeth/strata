-- Data only. Same shape as tanks.lua; stats.cargo_capacity = total volume the hold takes.
-- Costs: 9 copper plates for the copper hold, x1.3 per level (rounded). Placeholder values, not final.
return {
	id = "cargo",
	title = "Cargo hold",
	stat = {key = "cargo_capacity", label = "Capacity", unit = "vol"},
	levels = {
		{name = "stock", description = "Stock hold", stats = {cargo_capacity = 15}},
		{name = "copper", description = "Copper hold", stats = {cargo_capacity = 25}, from = {copper_plate = 9}},
		{name = "bronze", description = "Bronze hold", stats = {cargo_capacity = 38}, from = {bronze = 12}},
		{name = "steel", description = "Steel plate hold", stats = {cargo_capacity = 58}, from = {steel = 15}},
		{name = "nickel_steel", description = "Nickel steel hold", stats = {cargo_capacity = 85}, from = {nickel_steel = 20}},
		{name = "titanium", description = "Titanium alloy hold", stats = {cargo_capacity = 130}, from = {titanium_alloy = 26}},
		{name = "tungsten", description = "Tungsten carbide hold", stats = {cargo_capacity = 200}, from = {tungsten_carbide = 33}},
		{name = "deep", description = "Deep alloy hold", stats = {cargo_capacity = 300}, from = {deep_alloy = 43}},
		{name = "platinum", description = "Platinum alloy hold", stats = {cargo_capacity = 450}, from = {platinum_alloy = 56}},
		{name = "core", description = "Core alloy hold", stats = {cargo_capacity = 700}, from = {core_alloy = 73}},
	},
}
