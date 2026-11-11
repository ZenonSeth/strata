local constants = st_utils.constants
local storage = core.get_mod_storage()

-- name -> {name, description, kind, from = {material = amount}, price, fuel_cost}
-- kind is "material" (a smelter recipe) or an upgrade category id ("tank", "hull"). The list keeps registration order.
st_recipes.items = {}
st_recipes.list = {}

local material_recipes = {}

local function add(def)
	st_recipes.items[def.name] = def
	st_recipes.list[#st_recipes.list + 1] = def
end

for _, mat in ipairs(st_materials.list) do
	if mat.kind == "smelted" then
		local def = {
			name = mat.name, description = mat.description, kind = "material",
			from = mat.from, fuel_cost = mat.fuel_cost,
			price = mat.price * constants.recipe_price_mult,
		}
		add(def)
		material_recipes[#material_recipes + 1] = def
	end
end

-- Two significant digits, like material prices
local function round2(price)
	local unit = 1
	while price / unit >= 100 do
		unit = unit * 10
	end
	return math.floor(price / unit + 0.5) * unit
end

-- Market price of the materials a level is built from
local function build_cost(from)
	local cost = 0
	for material, amount in pairs(from) do
		cost = cost + st_materials.get(material).price * amount
	end
	return cost
end

-- Recipe name of an upgrade level, e.g. ("tank", "copper") -> "tank:copper"
function st_recipes.level_recipe(category_id, level_name)
	return category_id .. ":" .. level_name
end

for _, category in ipairs(st_machine_data.upgrades) do
	for _, level in ipairs(category.levels) do
		if level.from then
			add({
				name = st_recipes.level_recipe(category.id, level.name), description = level.description, kind = category.id,
				from = level.from, open = level.open,
				price = level.recipe_price or round2(build_cost(level.from) * constants.upgrade_recipe_mult),
			})
		end
	end
end

function st_recipes.get(name)
	return st_recipes.items[name]
end

-- Per-player sets of material names and owned recipe names, kept in mod storage as JSON
local cache = {}

local function load(kind, player_name)
	local key = kind .. ":" .. player_name
	if not cache[key] then
		local raw = storage:get_string(key)
		cache[key] = raw ~= "" and core.parse_json(raw) or {}
	end
	return cache[key], key
end

local function save(kind, player_name)
	local set, key = load(kind, player_name)
	storage:set_string(key, core.write_json(set))
end

local discover_listeners = {}

-- fn(player, material_name) runs once for each material the player newly found or can now make
function st_recipes.register_on_discover(fn)
	discover_listeners[#discover_listeners + 1] = fn
end

local function all_found(found, from)
	for input in pairs(from) do
		if not found[input] then
			return false
		end
	end
	return true
end

-- Fuel is not an input, so a recipe is reachable once all its listed inputs are found
local function discover(player, names)
	local player_name = player:get_player_name()
	local found = load("found", player_name)
	local new = {}
	for _, name in ipairs(names) do
		if not found[name] then
			found[name] = true
			new[#new + 1] = name
		end
	end
	if #new == 0 then
		return
	end
	local changed = true
	while changed do
		changed = false
		for _, def in ipairs(material_recipes) do
			if not found[def.name] and all_found(found, def.from) then
				found[def.name] = true
				new[#new + 1] = def.name
				changed = true
			end
		end
	end
	save("found", player_name)
	for _, name in ipairs(new) do
		for _, fn in ipairs(discover_listeners) do
			fn(player, name)
		end
	end
end

function st_recipes.has_found(player, material)
	return load("found", player:get_player_name())[material] == true
end

-- Raw materials the hold has ever contained are found; so is anything they can reach
local function scan_cargo(player)
	local names = {}
	for name in pairs(st_machine.cargo.get(player)) do
		names[#names + 1] = name
	end
	table.sort(names)
	discover(player, names)
end

st_machine.cargo.register_on_change(scan_cargo)

core.register_on_joinplayer(scan_cargo)

function st_recipes.has(player, name)
	return load("owned", player:get_player_name())[name] == true
end

-- Whether an input is found, or is smelted straight from raws and any of those is found
local function near(found, input)
	if found[input] then
		return true
	end
	local made = st_recipes.items[input]
	if not (made and made.kind == "material") then
		return false
	end
	for raw in pairs(made.from) do
		local raw_made = st_recipes.items[raw]
		if found[raw] and not (raw_made and raw_made.kind == "material") then
			return true
		end
	end
	return false
end

-- Whether any input of the recipe is found or one smelting step from a found raw material
function st_recipes.has_progress(player, name)
	local def = st_recipes.items[name]
	if not def then
		return false
	end
	if def.open then
		return true
	end
	local found = load("found", player:get_player_name())
	for input in pairs(def.from) do
		if near(found, input) then
			return true
		end
	end
	return false
end

-- Whether every input of the recipe has been found
function st_recipes.is_available(player, name)
	local def = st_recipes.items[name]
	return def ~= nil and (def.open or all_found(load("found", player:get_player_name()), def.from))
end

function st_recipes.can_buy(player, name)
	return st_recipes.is_available(player, name) and not st_recipes.has(player, name)
end

-- Gives the recipe without checking or charging; returns false if unknown or already owned
function st_recipes.unlock(player, name)
	if not st_recipes.items[name] or st_recipes.has(player, name) then
		return false
	end
	local player_name = player:get_player_name()
	load("owned", player_name)[name] = true
	save("owned", player_name)
	return true
end

core.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	cache["found:" .. player_name], cache["owned:" .. player_name] = nil, nil
end)
