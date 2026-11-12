-- Data only (also loaded by the mapgen script). curve as in materials.lua.
-- Caverns are half-ellipsoids open to the slice and reaching back into the backing wall.
-- rarity = fraction of slice nodes that are cavern at weight 1. Sizes are in nodes, not scaled:
-- radius is the x radius at the slice (y is up to as large, either way round), depth is how far
-- behind the slice a cavern reaches (picked per cavern, mostly shallow).
return {
	rarity = 2e-3,
	min_radius = 4, max_radius = 20,
	min_depth = 6, max_depth = 60,
	curve = {
		{2000, 0}, {3000, 1}, {60000, 1}, {60001, 0},
	},
}
