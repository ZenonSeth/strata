-- Data only. Placeholder recipes: from = {material = amount}. Volume is 1, weight the sum of the inputs,
-- and the price is REFINE_MARKUP times the inputs (see init.lua), unless set here.
-- Not listed yet: the fuel grade a recipe needs. Order matters: inputs come before what they make.
return {
	{name = "copper_plate", description = "Copper plate", from = {copper = 1}},
	{name = "bronze", description = "Bronze", from = {copper = 1, tin = 1}},
	{name = "iron_plate", description = "Iron plate", from = {iron = 1, coal = 1}},
	{name = "steel", description = "Steel", from = {iron = 1, coal = 1}},
	{name = "nickel_steel", description = "Nickel steel", from = {iron = 1, nickel = 1}},
	{name = "titanium_alloy", description = "Titanium alloy", from = {titanium = 1, oil = 1}},
	{name = "tungsten_carbide", description = "Tungsten carbide", from = {tungsten = 1, graphite = 1}},
	{name = "deep_alloy", description = "Deep alloy", from = {steel = 1, oil = 1}},
	{name = "platinum_alloy", description = "Platinum alloy", from = {platinum = 1, steel = 1}},
	{name = "core_alloy", description = "Core alloy", from = {core_ore = 1, lava = 1}},
	{name = "lens_glass", description = "Lens glass", from = {quartz = 1, coal = 1}},
	{name = "fine_wiring", description = "Fine wiring", from = {gold = 1, coal = 1}},
}
