-- Data only. Same shape as tanks.lua; stats.move_speed = sideways top speed (nodes/s), stats.fuel_use = multiplier on all fuel burn.
-- Speed rises about 2.6x and burn 2x, while tanks grow far faster, so a matched tank and engine run longer.
-- Costs: mostly exotic raws (sulphur, graphite, nickel, uranium) and one gem from level 7. Placeholder values, not final.
return {
	id = "engine",
	title = "Engine",
	stat = {key = "move_speed", label = "Speed", unit = "n/s"},
	extra = {{key = "fuel_use", label = "Fuel use", format = "x%g"}},
	levels = {
		{name = "stock", description = "Stock motor", stats = {move_speed = 3.5, fuel_use = 1}},
		{name = "inline4", description = "Inline-4 engine", stats = {move_speed = 4.5, fuel_use = 1.1},
			from = {aluminum_plate = 8, copper_wire = 8}},
		{name = "turbo_inline4", description = "Turbo Inline-4 engine", stats = {move_speed = 5.25, fuel_use = 1.2},
			from = {aluminum_plate = 10, nickel = 8, graphite = 8}},
		{name = "v6", description = "V6 engine", stats = {move_speed = 6, fuel_use = 1.3},
			from = {nickel_steel = 8, graphite = 10, sulphur = 10}},
		{name = "twin_turbo_v6", description = "Twin-turbo V6 engine", stats = {move_speed = 6.5, fuel_use = 1.4},
			from = {titanium_alloy = 8, silver_wire = 8, nickel = 10}},
		{name = "v8", description = "V8 engine", stats = {move_speed = 7, fuel_use = 1.5},
			from = {titanium_alloy = 10, tungsten_carbide = 6, quartz = 8, silver_wire = 8}},
		{name = "supercharged_v8", description = "Supercharged V8 engine", stats = {move_speed = 7.5, fuel_use = 1.6},
			from = {deep_alloy = 8, topaz = 6, graphite = 12, sulphur = 10}},
		{name = "v12", description = "V12 engine", stats = {move_speed = 8, fuel_use = 1.7},
			from = {platinum_alloy = 8, ruby = 6, graphite = 12}},
		{name = "alpha_v8", description = "Alpha-boosted V8 engine", stats = {move_speed = 8.5, fuel_use = 1.8},
			from = {platinum_alloy = 8, sapphire = 6, uranium = 12}},
		{name = "gamma_v12", description = "Gamma-boosted V12 engine", stats = {move_speed = 9, fuel_use = 2},
			from = {core_alloy = 8, diamond = 6, uranium = 14}},
	},
}
