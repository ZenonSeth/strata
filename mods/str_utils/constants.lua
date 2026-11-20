-- Plain data (also loaded by the mapgen script, where mod globals do not exist)
return {
	-- y of the topmost ground node (the sand row)
	surface_y = 0,
	-- z of the gameplay slice; terrain exists only at and behind it, up to back_depth behind
	slice_z = 2,
	back_depth = 100,
	-- The playable world: x runs from -world_half_width to world_half_width, and y from the height
	-- above the surface down to the depth below it (both in unscaled metres, times DEPTH_SCALE)
	world_half_width = 2000,
	-- Surface biomes west to east, each an x range (contiguous; the mapgen roughens the edges)
	biomes = {
		{name = "snow", x_start = -2000, x_end = -700},
		{name = "grass", x_start = -700, x_end = 700},
		{name = "sand", x_start = 700, x_end = 2000},
	},
	world_height = 30000,
	world_depth = 31000,
	-- x of each surface building: the shop's column with the entrance (the machine starts at its pad),
	-- and the left column of the refinery and the company contact
	shop_x = -7,
	refinery_x = 4,
	contact_x = -20,
	-- Player interiors, one row of session slots high above the world: slot n is at origin + (n * spacing, 0, 0).
	-- A slot is held from join to leave and placed fresh each session, so `slots` caps players online
	interior = {origin = {x = -30720, y = 30000, z = -30720}, spacing = 64, slots = 960},
	-- Landing speed (nodes/s) below which a machine landing makes no sound and does no damage
	min_impact_speed = 10.9,
	-- Terminal fall speed of a machine (nodes/s); landings at this speed do max_fall_damage
	max_fall_speed = 30,
	-- Hull damage of a landing at terminal fall speed; scales linearly from 0 at min_impact_speed
	max_fall_damage = 150,
	-- Machine in any liquid: sideways speed multiplier, climb top speed as a fraction of thrust, terminal fall speed (nodes/s);
	-- collecting a damaging source (lava) counts as collect_exposure seconds in it
	liquid = {speed_mult = 0.5, climb_speed_mult = 0.1, max_fall_speed = 4, collect_exposure = 1},
	-- Gas pockets (str_gas): depths in unscaled metres like strata.lua. The chance per drilled stratum node grows
	-- geometrically from min_chance at start_depth to max_chance at world_depth; damage grows linearly to damage * max_damage_mult.
	-- Jim's warning mail goes out warning_distance above start_depth
	gas = {start_depth = 12000, warning_distance = 2000, min_chance = 1e-5, max_chance = 1e-3,
		damage = 50, max_damage_mult = 2},
	-- Hot rock veins from the top of from_stratum down; sizes in nodes, {top, world bottom} pairs change linearly with depth
	hot_rock = {from_stratum = "schist", spacing = {200, 50}, thickness = {1, 3}, wobble = 8, wobble_spread = 120,
		gap_period = 200, gap_length = {15, 45}, light = 10, damage_seconds = 3, heat_seconds = 2, cool_hold = 2},
	-- Share of a falling rock's downward speed handed to the machine it hits
	rock_momentum_transfer = 0.5,
	fuel = {
		-- Litres per second while driving sideways (the stock 20 L tank lasts 4 minutes), whatever the tank size
		burn_per_second = 25 / 300,
		-- Burn rate multipliers on burn_per_second
		dig_mult = 2,
		climb_mult = 1.5,
		-- Empty tank: sideways and climb top speeds are this fraction of the current stats
		empty_speed_mult = 0.1,
		-- Credits per litre at the pump
		price_per_litre = 1,
	},
	-- Display units; the escape is UTF-8 superscript 3
	volume_unit = "m\194\179",
	weight_unit = "T",
	-- Total volume the mechanic shop storage holds; it has no weight limit
	storage_capacity = 100000,
	-- Cargo crates dropped in the world: volume each holds (no weight limit) and how many one player may have
	cargo_crate = {capacity = 500, per_player = 50},
	-- Recipe price = this times the sell price of what a smelter recipe makes
	recipe_price_mult = 8,
	-- Upgrade recipe price = this times the market price of the materials the part is built from
	upgrade_recipe_mult = 4,
	-- Credits per hit point the repair station charges for the stock hull (other hulls cost materials)
	repair_price_per_hp = 2,
	-- Credits per MJ the refuel station charges to recharge a laser battery
	recharge_price_per_mj = 5,
	-- Story: what the player owes the company at the start, in credits
	story = {starting_debt = 10000000},
	-- Player mail: max subject and body length (bytes), seconds between sends, sent copies kept
	mail = {subject_max = 60, text_max = 2000, cooldown = 10, sent_max = 100},
	-- Gauge bar colors, shared by the HUD and the station windows
	colors = {hull = "#b85450", fuel = "#4f9a60", cargo = "#b8923a", heat = "#e07a20"},
	-- kinds of interior node use; nodes are tagged with one, game logic listens for it
	interact = {
		upgrade = "upgrade",
		refuel = "refuel",
		repair = "repair",
		warehouse = "warehouse",
		terminal = "terminal",
		sleep = "sleep",
		drive = "drive",
		manual = "manual",
	},
}
