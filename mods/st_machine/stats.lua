local stats = {}

local META_KEY = "st_machine:upgrades"

stats.base = {
	-- Horizontal top speed (nodes/s)
	move_speed = 3.5,
	-- Dig time is st_hardness / dig_speed
	dig_speed = 0.5,
	-- Max climb speed (nodes/s) with an empty hold
	thrust = 3,
	can_dig_up = false,
	-- Total cargo volume the hold can take
	cargo_capacity = 10,
	-- Size of the fuel tank
	max_fuel = 100,
	-- Hit points; the machine is destroyed at 0
	max_hull = 100,
	-- Depth (y) where darkness is full; it starts at y = -10 (see st_environment)
	light_fade_end = -50,
	-- Vignette opacity at full darkness (0..1); light upgrades lower it, st_environment floors it at 0.25
	vignette_max = 0.75,
}

-- Applying an upgrade overwrites these stat values
stats.upgrades = {
	dig_up = {can_dig_up = true},
}

local cache = {}

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

function stats.get(player)
	local name = player:get_player_name()
	if cache[name] then
		return cache[name]
	end
	local result = table.copy(stats.base)
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

function stats.reset_upgrades(player)
	player:get_meta():set_string(META_KEY, "[]")
	cache[player:get_player_name()] = nil
end

function stats.forget(player)
	cache[player:get_player_name()] = nil
end

return stats
