-- Data only. Same shape as tanks.lua; stats.thrust = top climb speed, stats.thrust_rating = cargo weight the thrusters are built to carry.
-- Levels match the cargo levels one to one. Climb speed rises 0.5 per level; the rating is the weight of a full hold of gold
-- of the matched cargo level (stock keeps a hand-set rating), at which the climb acceleration is 10% of the empty-hold one.
-- kind (propeller, jet, rocket) picks the exhaust particles in st_machine/base.lua; only jets and rockets can dig upwards.
-- Costs: 10 of the matched cargo level's material for the propellers, more of it plus graphite, oil, sulphur or uranium for jets and rockets. Placeholder values, not final.
local STOCK_SPEED = 2.25
local SPEED_STEP = 0.5
local STOCK_RATING = 45

local cargo = st_machine_data.get_upgrade("cargo")
local gold = st_materials.get("gold")
local gold_per_volume = gold.weight / gold.volume

local names = {"Stock propeller", "Copper-sheathed propeller", "Bronze propeller", "Steel propeller",
	"Variable-pitch propeller", "Turbojet", "Turbofan", "Afterburning turbofan", "Chemical rocket", "Nuclear rocket"}
local kinds = {"propeller", "propeller", "propeller", "propeller", "propeller", "jet", "jet", "jet", "rocket", "rocket"}
local alloy_amounts = {10, 10, 10, 10, 13, 17, 22, 28, 37}
-- Jets and rockets need more than the alloy, keyed by level index
local extras = {
	[6] = {graphite = 8},
	[7] = {graphite = 10, oil = 6},
	[8] = {graphite = 12, oil = 8},
	[9] = {sulphur = 12, oil = 10},
	[10] = {uranium = 14, graphite = 12},
}

local levels = {}
for i, cargo_level in ipairs(cargo.levels) do
	local level = {
		name = cargo_level.name,
		description = names[i],
		kind = kinds[i],
		stats = {
			thrust = STOCK_SPEED + SPEED_STEP * (i - 1),
			thrust_rating = i == 1 and STOCK_RATING or gold_per_volume * cargo_level.stats.cargo_capacity,
			can_dig_up = kinds[i] ~= "propeller",
		},
	}
	if i > 1 then
		local material = next(cargo_level.from)
		level.from = {[material] = alloy_amounts[i - 1]}
		for extra, amount in pairs(extras[i] or {}) do
			level.from[extra] = amount
		end
	end
	levels[i] = level
end

return {
	id = "thrusters",
	title = "Thrusters",
	stat = {key = "thrust", label = "Climb speed", unit = "m/s"},
	extra = {
		{key = "thrust_rating", label = "Rated load", format = "%g"},
		{key = "can_dig_up", label = "Dig up", names = {[true] = "Yes", [false] = "No"}, width = 5},
	},
	levels = levels,
}
