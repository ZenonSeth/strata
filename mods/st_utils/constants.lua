-- Plain data (also loaded by the mapgen script, where mod globals do not exist)
return {
	-- y of the topmost ground node (the sand row)
	surface_y = 0,
	-- z of the gameplay slice; terrain exists only at and behind it
	slice_z = 2,
	-- x of each surface building: the shop's column with the entrance (the machine starts at its pad),
	-- and the left column of the refinery and the company contact
	shop_x = -7,
	refinery_x = 4,
	contact_x = -20,
	-- Player interiors, one schematic copy each, in a grid in front of the world (terrain only exists at
	-- z >= slice_z): slot n is at origin + (n % columns, 0, -(n // columns)) * spacing
	interior = {origin = {x = 0, y = 0, z = -1000}, spacing = 500, columns = 16},
	-- kinds of interior node use; nodes are tagged with one, game logic listens for it
	interact = {
		upgrade = "upgrade",
		refuel = "refuel",
		repair = "repair",
		warehouse = "warehouse",
		terminal = "terminal",
		sleep = "sleep",
		drive = "drive",
	},
}
