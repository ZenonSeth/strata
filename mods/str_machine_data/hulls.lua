-- Data only. Same shape as tanks.lua; stats.max_hull = hit points, stats.hull_slots = hull upgrade slots,
-- stats.heat_time = seconds of lava protection before the hull overheats (hidden).
-- Costs: 10 copper plates for the copper hull, x1.5 per level up to titanium, x1.25 after (rounded).
-- condition: every part keeps its own current value of its stat (hit points), starting at the max.
return {
	id = "hull",
	title = "Hull",
	stat = {key = "max_hull", label = "Hit points"},
	extra = {{key = "hull_slots", label = "Upgrade slots", column = false}},
	condition = true,
	levels = {
		{name = "stock", description = "Stock hull", stats = {max_hull = 50, hull_slots = 0, heat_time = 0}},
		{name = "copper", description = "Copper hull", stats = {max_hull = 75, hull_slots = 0, heat_time = 0}, from = {copper_plate = 10}},
		{name = "bronze", description = "Bronze hull", stats = {max_hull = 115, hull_slots = 0, heat_time = 0}, from = {bronze = 15}},
		{name = "steel", description = "Steel plate hull", stats = {max_hull = 170, hull_slots = 1, heat_time = 5}, from = {steel = 23}},
		{name = "nickel_steel", description = "Nickel steel hull", stats = {max_hull = 260, hull_slots = 1, heat_time = 8}, from = {nickel_steel = 34}},
		{name = "titanium", description = "Titanium alloy hull", stats = {max_hull = 390, hull_slots = 2, heat_time = 12}, from = {titanium_alloy = 51}},
		{name = "tungsten", description = "Tungsten carbide hull", stats = {max_hull = 590, hull_slots = 2, heat_time = 16}, from = {tungsten_carbide = 63}},
		{name = "deep", description = "Deep alloy hull", stats = {max_hull = 880, hull_slots = 2, heat_time = 20}, from = {deep_alloy = 79}},
		{name = "platinum", description = "Platinum alloy hull", stats = {max_hull = 1300, hull_slots = 3, heat_time = 25}, from = {platinum_alloy = 99}},
		{name = "core", description = "Core alloy hull", stats = {max_hull = 2000, hull_slots = 3, heat_time = 30}, from = {core_alloy = 124}},
	},
}
