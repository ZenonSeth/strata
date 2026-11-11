-- Data only. Same shape as tanks.lua; stats.light_min = lowest day/night ratio (0..1) the world dims to, stats.vignette_max = dark edge opacity at full darkness.
-- recipe_price overrides the recipe's credit price and open makes it buyable at once (no discovery gate).
-- Costs: placeholder values, not final.
return {
	id = "lights",
	title = "Lights",
	stat = {key = "light_min", label = "Effect", names = {
		[0] = "None",
		[0.5] = "Dimly lights up the darkness",
		[0.7] = "Lights up the darkness brightly",
	}},
	levels = {
		{name = "stock", description = "No lights", stats = {light_min = 0, vignette_max = 0.75}},
		{name = "dim", description = "Dim Vehicle Lights", stats = {light_min = 0.5, vignette_max = 0.75},
			from = {copper_wire = 1, copper_plate = 1}, recipe_price = 99.95, open = true},
		{name = "bright", description = "Bright Vehicle Lights", stats = {light_min = 0.7, vignette_max = 0.3},
			from = {lens_glass = 6, silver_wire = 4}},
	},
}
