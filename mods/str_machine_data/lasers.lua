-- Lasers and batteries made in the Create Items tab. Energy is in kJ, range in nodes.
-- A laser or battery with a blueprint gets an "item:<name>" recipe; the smallest battery and the mount need any laser blueprint.
return {
	lasers = {
		{name = "laser_red", item = "str_lasers:laser_red", description = "Red laser", color = "#ff3a2a",
			tier = 6, shot_kj = 500, range = 4,
			from = {copper_wire = 4, aluminum_plate = 2, lens_glass = 2, ruby = 1}},
		{name = "laser_green", item = "str_lasers:laser_green", description = "Green laser", color = "#3aff4a",
			tier = 7, shot_kj = 2000, range = 6,
			from = {silver_wire = 4, nickel_steel = 3, lens_glass = 3, emerald = 1}},
		{name = "laser_blue", item = "str_lasers:laser_blue", description = "Blue laser", color = "#3a7aff",
			tier = 9, shot_kj = 6000, range = 8,
			from = {gold_wire = 4, titanium_alloy = 3, lens_glass = 4, sapphire = 1}},
	},
	batteries = {
		{name = "battery_small", item = "str_lasers:battery_small", description = "Small battery", capacity_kj = 5000,
			from = {copper_plate = 2, lead = 4}},
		{name = "battery_medium", item = "str_lasers:battery_medium", description = "Battery", capacity_kj = 20000,
			blueprint = true, from = {nickel_steel = 2, silver_wire = 2, lead = 6}},
		{name = "battery_large", item = "str_lasers:battery_large", description = "Large battery", capacity_kj = 80000,
			blueprint = true, from = {aluminum_plate = 4, gold_wire = 2, nickel = 6}},
		{name = "battery_huge", item = "str_lasers:battery_huge", description = "Huge battery", capacity_kj = 250000,
			blueprint = true, from = {titanium_alloy = 4, gold_wire = 2, platinum = 2}},
	},
	mount = {item = "str_machine:hull_laser_mount", description = "Laser mounting point",
		info = "Hull upgrade, needed to fire any laser", image = "str_machine_hull_laser_mount.png",
		from = {steel = 6, copper_wire = 4}},
}
