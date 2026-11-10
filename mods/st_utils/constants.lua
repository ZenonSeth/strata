-- Plain data (also loaded by the mapgen script, where mod globals do not exist)
return {
	-- y of the topmost ground node (the sand row)
	surface_y = 0,
	-- z of the gameplay slice; terrain exists only at and behind it
	slice_z = 2,
	-- The playable world: x runs from -world_half_width to world_half_width, and y from the height
	-- above the surface down to the depth below it (both in unscaled metres, times DEPTH_SCALE)
	world_half_width = 2000,
	world_height = 30000,
	world_depth = 31000,
	-- x of each surface building: the shop's column with the entrance (the machine starts at its pad),
	-- and the left column of the refinery and the company contact
	shop_x = -7,
	refinery_x = 4,
	contact_x = -20,
	-- Player interiors, one schematic copy each, in a grid in front of the world (terrain only exists at
	-- z >= slice_z): slot n is at origin + (n % columns, 0, -(n // columns)) * spacing
	interior = {origin = {x = 0, y = 0, z = -1000}, spacing = 500, columns = 16},
	-- Landing speed (nodes/s) below which a machine landing makes no sound and does no damage
	min_impact_speed = 10.9,
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
