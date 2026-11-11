-- Data only. Placeholder recipes: from = {material = amount}. A recipe from a single ore (plus an additive) takes 2 of it; ore + ore or smelted + ore is 1 + 1.
-- Volume is 1, weight the sum of the inputs, and the price is REFINE_MARKUP times the inputs (see init.lua), unless set here.
-- fuel_cost is in fuel units (see fuels.lua; placeholder values). Order matters: inputs come before what they make; the refinery lists them in this order.
return {
	{name = "copper_plate", description = "Copper plate", from = {copper = 2}, fuel_cost = 1},
	{name = "copper_wire", description = "Copper wire", from = {copper = 1}, fuel_cost = 1},
	{name = "bronze", description = "Bronze", from = {copper = 1, tin = 1}, fuel_cost = 1},
	{name = "steel", description = "Steel plate", from = {iron = 2, coal = 1}, fuel_cost = 2},
	{name = "silver_wire", description = "Silver wire", from = {silver = 1}, fuel_cost = 1},
	{name = "lens_glass", description = "Lens glass", from = {quartz = 2}, fuel_cost = 1},
	{name = "nickel_steel", description = "Nickel steel", from = {iron = 1, nickel = 1}, fuel_cost = 2},
	{name = "hardened_steel", description = "Hardened steel", from = {steel = 1, nickel = 1}, fuel_cost = 3},
	{name = "aluminum_plate", description = "Aluminum plate", from = {aluminum = 2, graphite = 1}, fuel_cost = 3},
	{name = "fine_wiring", description = "Fine wiring", from = {gold = 1}, fuel_cost = 1},
	{name = "titanium_alloy", description = "Titanium alloy", from = {titanium = 2, oil = 1}, fuel_cost = 4},
	{name = "tungsten_carbide", description = "Tungsten carbide", from = {tungsten = 2, graphite = 1}, fuel_cost = 5},
	{name = "deep_alloy", description = "Deep alloy", from = {nickel_steel = 2, titanium = 1}, fuel_cost = 6},
	{name = "platinum_alloy", description = "Platinum alloy", from = {platinum = 1, steel = 1}, fuel_cost = 8},
	{name = "core_alloy", description = "Core alloy", from = {core_ore = 2, lava = 1}, fuel_cost = 12},
}
