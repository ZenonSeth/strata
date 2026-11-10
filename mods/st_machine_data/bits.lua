-- Data only. hardness = Mohs-like, cuts = highest node tier it digs (hardness - 1). Placeholder values.
-- from = materials needed; a nested table means any one of them; tip/body for gem-tipped bits.
return {
	{name = "rusted_iron", description = "Rusted iron bit", hardness = 2, cuts = 1, obtainable = false},
	{name = "copper_repaired_iron", description = "Copper-repaired rusted iron bit", hardness = 3, cuts = 2, from = {"copper"}},
	{name = "bronze", description = "Bronze bit", hardness = 4, cuts = 3, from = {"copper", "tin"}},
	{name = "steel", description = "Steel bit", hardness = 5, cuts = 4, from = {"iron", {"coal", "graphite"}}},
	{name = "hardened_steel", description = "Hardened steel bit", hardness = 6, cuts = 5, from = {"steel", "nickel"}},
	{name = "quartz", description = "Quartz-tipped bit", hardness = 7, cuts = 6, tip = {"quartz"}, body = "hardened_steel"},
	{name = "topaz", description = "Topaz-tipped bit", hardness = 8, cuts = 7, tip = {"topaz"}, body = "tungsten_carbide"},
	{name = "sapphire", description = "Sapphire or ruby bit", hardness = 9, cuts = 8, tip = {"sapphire", "ruby"}, body = "tungsten_carbide"},
	{name = "diamond", description = "Diamond-tipped bit", hardness = 10, cuts = 9, tip = {"diamond"}, body = "tungsten_carbide"},
	{name = "dragonstone", description = "Dragonstone-tipped bit", hardness = 11, cuts = 10, tip = {"dragonstone"}, body = "tungsten_carbide"},
}
