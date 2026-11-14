-- Data only. Same shape as tanks.lua; stats.move_speed = sideways top speed (nodes/s), stats.fuel_use = multiplier on all fuel burn.
-- fuel_use = move_speed / 3.5, so fuel per node driven is the same at every level.
-- Costs: mostly exotic raws (sulphur, graphite, nickel, uranium) and one gem from level 7. Placeholder values, not final.
return {
	id = "engine",
	title = "Engine",
	stat = {key = "move_speed", label = "Speed", unit = "m/s"},
	extra = {{key = "fuel_use", label = "Fuel use", format = "x%g"}},
	levels = {
		{name = "stock", description = "Stock motor", stats = {move_speed = 3.5, fuel_use = 1}},
		{name = "inline4", description = "Inline-4 engine", stats = {move_speed = 4.5, fuel_use = 1.29},
			from = {aluminum_plate = 8, copper_wire = 8}},
		{name = "turbo_inline4", description = "Turbo Inline-4 engine", stats = {move_speed = 5.25, fuel_use = 1.5},
			from = {aluminum_plate = 10, nickel = 8, graphite = 8}},
		{name = "v6", description = "V6 engine", stats = {move_speed = 6, fuel_use = 1.71},
			from = {nickel_steel = 8, graphite = 10, sulphur = 10}},
		{name = "twin_turbo_v6", description = "Twin-turbo V6 engine", stats = {move_speed = 6.5, fuel_use = 1.86},
			from = {titanium_alloy = 8, silver_wire = 8, nickel = 10}},
		{name = "v8", description = "V8 engine", stats = {move_speed = 7, fuel_use = 2},
			from = {titanium_alloy = 10, tungsten_carbide = 6, quartz = 8, silver_wire = 8}},
		{name = "supercharged_v8", description = "Supercharged V8 engine", stats = {move_speed = 7.5, fuel_use = 2.14},
			from = {deep_alloy = 8, topaz = 6, graphite = 12, sulphur = 10}},
		{name = "v12", description = "V12 engine", stats = {move_speed = 8, fuel_use = 2.29},
			from = {platinum_alloy = 8, alexandrite = 6, graphite = 12}},
		{name = "alpha_v8", description = "Alpha-boosted V8 engine", stats = {move_speed = 8.5, fuel_use = 2.43},
			from = {platinum_alloy = 8, sapphire = 6, uranium = 12}},
		{name = "gamma_v12", description = "Gamma-boosted V12 engine", stats = {move_speed = 9, fuel_use = 2.57},
			from = {core_alloy = 8, diamond = 6, uranium = 14}},
	},
}
