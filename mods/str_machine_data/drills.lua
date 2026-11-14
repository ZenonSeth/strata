-- Data only. Same shape as tanks.lua; stats.drill_tier = highest node tier dug, stats.dig_speed (base 0.5).
-- extra = more stats the upgrade station shows beside the main one; scale/format only change how they are shown.
-- Costs: 10 of the level's alloy up to hardened steel, then 8 gems plus 12 body alloy. Placeholder values, not final.
-- Sapphire and alexandrite bits are the same tier; sapphire digs faster.
return {
	id = "drill",
	title = "Drill bit",
	stat = {key = "drill_tier", label = "Max tier"},
	extra = {{key = "dig_speed", label = "Speed", scale = 2, format = "x%g"}},
	levels = {
		{name = "stock", description = "Stock bit", stats = {drill_tier = 1, dig_speed = 0.5}},
		{name = "copper", description = "Copper-repaired iron bit", stats = {drill_tier = 2, dig_speed = 0.75},
			from = {copper_plate = 10}},
		{name = "bronze", description = "Bronze bit", stats = {drill_tier = 3, dig_speed = 1.5},
			from = {bronze = 10}},
		{name = "steel", description = "Steel bit", stats = {drill_tier = 4, dig_speed = 2},
			from = {steel = 10}},
		{name = "hardened_steel", description = "Hardened steel bit", stats = {drill_tier = 5, dig_speed = 3},
			from = {hardened_steel = 10}},
		{name = "quartz", description = "Quartz-tipped bit", stats = {drill_tier = 6, dig_speed = 4},
			from = {quartz = 8, hardened_steel = 12}},
		{name = "topaz", description = "Topaz-tipped bit", stats = {drill_tier = 7, dig_speed = 4.5},
			from = {topaz = 8, tungsten_carbide = 12}},
		{name = "alexandrite", description = "Alexandrite bit", stats = {drill_tier = 8, dig_speed = 5.5},
			from = {alexandrite = 8, tungsten_carbide = 12}},
		{name = "sapphire", description = "Sapphire-tipped bit", stats = {drill_tier = 8, dig_speed = 6},
			from = {sapphire = 8, tungsten_carbide = 12}},
		{name = "diamond", description = "Diamond-tipped bit", stats = {drill_tier = 9, dig_speed = 6.5},
			from = {diamond = 8, tungsten_carbide = 12}},
		{name = "dragonstone", description = "Dragonstone bit", stats = {drill_tier = 10, dig_speed = 7.5},
			from = {dragonstone = 8, tungsten_carbide = 12}},
	},
}
