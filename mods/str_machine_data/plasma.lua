-- The plasma torch and its cells, made in the Create Items tab. Plasma is in seconds of burning, range in nodes.
-- The torch has a blueprint; the small cell needs the torch blueprint. Cells are refilled with uranium in Create Items
-- (refill_uranium for a full refill, charged per started share). Ingredients and numbers are placeholders.
return {
	torch = {name = "plasma_torch", item = "str_plasma:torch", description = "Plasma torch", color = "#c08aff",
		tier = 10, range = 4, dig_speed = 48, heat_capacity = 5, heat_per_second = 1,
		from = {platinum_alloy = 3, gold_wire = 4, lens_glass = 2, diamond = 1}},
	cells = {
		{name = "plasma_cell_small", item = "str_plasma:cell_small", description = "Small plasma cell", capacity_s = 30,
			refill_uranium = 10, from = {titanium_alloy = 2, uranium = 10}},
		{name = "plasma_cell_medium", item = "str_plasma:cell_medium", description = "Plasma cell", capacity_s = 60,
			refill_uranium = 20, blueprint = true, from = {tungsten_carbide = 2, gold_wire = 2, uranium = 20}},
		{name = "plasma_cell_large", item = "str_plasma:cell_large", description = "Large plasma cell", capacity_s = 90,
			refill_uranium = 30, blueprint = true, from = {platinum_alloy = 2, gold_wire = 2, uranium = 30}},
	},
	-- An overheated torch works again once the heat bar cools to this share of its capacity
	unlock_at = 0.8,
	-- Seconds the heat bar waits after burning before it cools
	cool_hold = 1,
}
