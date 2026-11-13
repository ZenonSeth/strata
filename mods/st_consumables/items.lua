local constants = st_utils.constants

-- One item per tier, at these tank and hull levels
local LEVELS = {1, 3, 5, 7, 9}
-- Share of the tank or hull each item restores
local FRACTION = 0.2
-- Price is this times the market value of what it restores
local PRICE_MULT = 2

st_consumables.sell_fraction = 0.5
-- Most a player can carry of one kind (fuel or repair), across all tiers
st_consumables.MAX_PER_KIND = 10
st_consumables.items = {}
st_consumables.order = {}

local function round2(x)
	return math.floor(x * 100 + 0.5) / 100
end

local function icon(kind, tier)
	local image = "st_consumables_" .. (kind == "fuel" and "fuel" or "repair") .. ".png"
	if tier > 1 then
		image = image .. "^st_consumables_tier" .. tier .. ".png"
	end
	return image
end

local function add(def)
	st_consumables.items[def.name] = def
	st_consumables.order[#st_consumables.order + 1] = def.name
end

local function build_cost(from)
	local cost = 0
	for material, amount in pairs(from) do
		cost = cost + st_materials.get(material).price * amount
	end
	return cost
end

local tanks = st_machine_data.get_upgrade("tank")
local hulls = st_machine_data.get_upgrade("hull")

for tier, index in ipairs(LEVELS) do
	local tank = tanks.levels[index]
	local litres = tank.stats.max_fuel * FRACTION
	add({
		name = "st_consumables:fuel_" .. tank.name, kind = "fuel", tier = tier, level = index,
		recipe = tank.from and ("tank:" .. tank.name) or nil, amount = litres,
		description = ("Fuel canister (%g L)"):format(litres), info = ("Refuels %g L"):format(litres),
		price = round2(litres * constants.fuel.price_per_litre * PRICE_MULT),
		image = icon("fuel", tier),
	})

	local hull = hulls.levels[index]
	local hp = hull.stats.max_hull * FRACTION
	local price = hull.from and build_cost(hull.from) * FRACTION * PRICE_MULT or hp * constants.repair_price_per_hp
	add({
		name = "st_consumables:repair_" .. hull.name, kind = "repair", tier = tier, level = index,
		recipe = hull.from and ("hull:" .. hull.name) or nil, amount = hp,
		description = ("Repair kit (%g HP)"):format(hp), price = round2(price),
		info = ("Repairs %g HP (%d%%)"):format(hp, FRACTION * 100), note = "Up to " .. hull.description,
		tooltip = "Repairs up to: " .. hull.description,
		image = icon("repair", tier),
	})
end
