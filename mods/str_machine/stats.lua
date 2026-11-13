local stats = {}

local META_KEY = "str_machine:upgrades"

stats.base = {
	-- Horizontal top speed (nodes/s)
	move_speed = str_machine_data.get_upgrade("engine").levels[1].stats.move_speed,
	-- Multiplier on all fuel burn
	fuel_use = str_machine_data.get_upgrade("engine").levels[1].stats.fuel_use,
	-- Dig time is str_hardness / dig_speed
	dig_speed = str_machine_data.get_upgrade("drill").levels[1].stats.dig_speed,
	-- Top climb speed (nodes/s); cargo weight lowers the climb acceleration, not this
	thrust = str_machine_data.get_upgrade("thrusters").levels[1].stats.thrust,
	-- Cargo weight the thrusters are built to carry (see RATED_DRAG in base.lua)
	thrust_rating = str_machine_data.get_upgrade("thrusters").levels[1].stats.thrust_rating,
	-- Set by the thrusters: only jets and rockets dig upwards
	can_dig_up = str_machine_data.get_upgrade("thrusters").levels[1].stats.can_dig_up,
	-- Highest node tier (str_tier) the drill bit digs; harder nodes are solid walls
	drill_tier = str_machine_data.get_upgrade("drill").levels[1].stats.drill_tier,
	-- Total cargo volume the hold can take
	cargo_capacity = str_machine_data.get_upgrade("cargo").levels[1].stats.cargo_capacity,
	-- Size of the fuel tank (litres)
	max_fuel = str_machine_data.get_upgrade("tank").levels[1].stats.max_fuel,
	-- Hit points; the machine is destroyed at 0
	max_hull = str_machine_data.get_upgrade("hull").levels[1].stats.max_hull,
	-- Depth (y) where darkness is full; it starts at y = -10 (see str_environment)
	light_fade_end = -50,
	-- Vignette opacity at full darkness (0..1); light upgrades lower it, str_environment floors it at 0.25
	vignette_max = str_machine_data.get_upgrade("lights").levels[1].stats.vignette_max,
	-- Lowest day/night ratio the world dims to; light upgrades raise it
	light_min = str_machine_data.get_upgrade("lights").levels[1].stats.light_min,
}

-- Applying an upgrade overwrites these stat values
stats.upgrades = {}

local cache = {}
local storage = core.get_mod_storage()

local function owned(player)
	local meta = player:get_meta()
	local raw = meta:get_string(META_KEY)
	if raw == "" then
		meta:set_string(META_KEY, "[]")
		return {}
	end
	local data = core.parse_json(raw)
	return type(data) == "table" and data or {}
end

-- Parts per category, in mod storage:
-- {id = {built = {level name = true}, equipped = level name, current = {level name = value}}}.
-- Built parts are kept; the equipped one (the stock level when none) is what the machine uses.
-- current is only for categories with condition (hull): a missing entry means the part is at its max.
local levels_cache = {}

local function levels_key(player)
	return "upgrades:" .. player:get_player_name()
end

local function built_levels(player)
	local key = levels_key(player)
	if not levels_cache[key] then
		local raw = storage:get_string(key)
		local data = raw ~= "" and core.parse_json(raw)
		levels_cache[key] = type(data) == "table" and data or {}
	end
	return levels_cache[key]
end

local listeners = {}

-- fn(player) runs after the player's built or equipped parts changed; re-read stats.get
function stats.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

-- silent: only a part's current value changed, so stats and listeners are left alone
local function save_levels(player, silent)
	storage:set_string(levels_key(player), core.write_json(built_levels(player)))
	if silent then
		return
	end
	cache[player:get_player_name()] = nil
	for _, fn in ipairs(listeners) do
		fn(player)
	end
end

local function level_index(category, name)
	for i, level in ipairs(category.levels) do
		if level.name == name then
			return i
		end
	end
end

local function is_built(entry, category, index)
	return index == 1 or (entry ~= nil and entry.built ~= nil and entry.built[category.levels[index].name] == true)
end

-- Index of the equipped level; the stock level when nothing valid is equipped
local function equipped_index(category, entry)
	local index = entry and level_index(category, entry.equipped)
	return index and is_built(entry, category, index) and index or 1
end

-- The level of a category the player has equipped; always a level (the stock one if nothing is built)
function stats.get_level(player, id)
	local category = str_machine_data.get_upgrade(id)
	if category then
		return category.levels[equipped_index(category, built_levels(player)[id])]
	end
end

function stats.has_level(player, id, level_name)
	local category = str_machine_data.get_upgrade(id)
	local index = category and level_index(category, level_name)
	return index ~= nil and is_built(built_levels(player)[id], category, index)
end

-- Current value of a condition category's part (the equipped one by default); nil for other categories
function stats.get_part_value(player, id, level_name)
	local category = str_machine_data.get_upgrade(id)
	if not category or not category.condition then
		return nil
	end
	local level = level_name and category.levels[level_index(category, level_name) or 0]
		or stats.get_level(player, id)
	local max = level.stats[category.stat.key]
	local entry = built_levels(player)[id]
	local value = entry and entry.current and entry.current[level.name]
	return math.min(value or max, max)
end

-- Clamps to 0..max; returns false for other categories or unknown levels
function stats.set_part_value(player, id, value, level_name)
	local category = str_machine_data.get_upgrade(id)
	if not category or not category.condition or (level_name and not level_index(category, level_name)) then
		return false
	end
	local level = level_name and category.levels[level_index(category, level_name)] or stats.get_level(player, id)
	local entry = built_levels(player)[id] or {}
	entry.current = entry.current or {}
	entry.current[level.name] = math.max(0, math.min(value, level.stats[category.stat.key]))
	built_levels(player)[id] = entry
	save_levels(player, true)
	return true
end

-- Marks a part built (kept until equipped and lost); returns false for an unknown or stock level.
-- Materials are the caller's business
function stats.build_level(player, id, level_name)
	local category = str_machine_data.get_upgrade(id)
	local index = category and level_index(category, level_name)
	if not index or index == 1 then
		return false
	end
	local entry = built_levels(player)[id] or {}
	entry.built = entry.built or {}
	entry.built[level_name] = true
	built_levels(player)[id] = entry
	save_levels(player)
	return true
end

local equip_checks = {}

-- fn(player, level) -> ok, reason: can veto equipping a level of a category (also the stock one)
function stats.register_equip_check(id, fn)
	equip_checks[id] = equip_checks[id] or {}
	table.insert(equip_checks[id], fn)
end

-- Returns ok, reason; the reason says why a level cannot be equipped
function stats.can_equip(player, id, level_name)
	local category = str_machine_data.get_upgrade(id)
	local index = category and level_index(category, level_name)
	if not index or not is_built(built_levels(player)[id], category, index) then
		return false, "Not built."
	end
	for _, check in ipairs(equip_checks[id] or {}) do
		local ok, reason = check(player, category.levels[index])
		if not ok then
			return false, reason or "Cannot be equipped now."
		end
	end
	return true
end

-- Equips a built part (the stock level takes the equipped one off); returns ok, reason
function stats.equip_level(player, id, level_name)
	local ok, reason = stats.can_equip(player, id, level_name)
	if not ok then
		return false, reason
	end
	local entry = built_levels(player)[id] or {}
	entry.equipped = level_name
	built_levels(player)[id] = entry
	save_levels(player)
	return true
end

-- Deletes a built part (and its condition); an equipped one falls back to the stock level. Returns ok, reason
function stats.remove_level(player, id, level_name)
	local category = str_machine_data.get_upgrade(id)
	local index = category and level_index(category, level_name)
	if not index or index == 1 then
		return false, "The stock part cannot be removed."
	end
	local entry = built_levels(player)[id]
	if not is_built(entry, category, index) then
		return false, "Not built."
	end
	if entry.equipped == level_name then
		local ok, reason = stats.can_equip(player, id, category.levels[1].name)
		if not ok then
			return false, reason
		end
		entry.equipped = nil
	end
	entry.built[level_name] = nil
	if entry.current then
		entry.current[level_name] = nil
	end
	save_levels(player)
	return true
end

function stats.get(player)
	local name = player:get_player_name()
	if cache[name] then
		return cache[name]
	end
	local result = table.copy(stats.base)
	for _, category in ipairs(str_machine_data.upgrades) do
		local level = stats.get_level(player, category.id)
		for key, value in pairs(level.stats) do
			result[key] = value
		end
	end
	for _, upgrade in ipairs(owned(player)) do
		for key, value in pairs(stats.upgrades[upgrade] or {}) do
			result[key] = value
		end
	end
	cache[name] = result
	return result
end

function stats.add_upgrade(player, upgrade)
	if not stats.upgrades[upgrade] then
		return false
	end
	local list = owned(player)
	for _, name in ipairs(list) do
		if name == upgrade then
			return true
		end
	end
	list[#list + 1] = upgrade
	player:get_meta():set_string(META_KEY, core.write_json(list))
	cache[player:get_player_name()] = nil
	return true
end

-- Death: the equipped parts are destroyed, built ones that were not equipped stay
function stats.reset_upgrades(player)
	player:get_meta():set_string(META_KEY, "[]")
	for id, entry in pairs(built_levels(player)) do
		local category = str_machine_data.get_upgrade(id)
		if entry.equipped and category and entry.equipped ~= category.levels[1].name then
			if entry.built then
				entry.built[entry.equipped] = nil
			end
			if entry.current then
				entry.current[entry.equipped] = nil
			end
		end
		entry.equipped = nil
		if not next(entry.built or {}) and not next(entry.current or {}) then
			built_levels(player)[id] = nil
		end
	end
	save_levels(player)
end

-- Removes every part, built or equipped (debugging)
function stats.reset_all_upgrades(player)
	player:get_meta():set_string(META_KEY, "[]")
	levels_cache[levels_key(player)] = {}
	save_levels(player)
end

function stats.forget(player)
	cache[player:get_player_name()] = nil
	levels_cache[levels_key(player)] = nil
end

str_machine.stats = stats
