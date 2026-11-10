local cargo = {}

local META_KEY = "st_machine:cargo"

local items = {}
local cache = {}

-- def: {volume = ..., weight = ...} per unit
function cargo.register_item(name, def)
	items[name] = {volume = def.volume, weight = def.weight}
end

local function contents(player)
	local name = player:get_player_name()
	if not cache[name] then
		local meta = player:get_meta()
		local raw = meta:get_string(META_KEY)
		if raw == "" then
			meta:set_string(META_KEY, "{}")
			cache[name] = {}
		else
			local data = core.parse_json(raw)
			cache[name] = type(data) == "table" and data or {}
		end
	end
	return cache[name]
end

local listeners = {}

-- fn(player) runs after the hold contents change
function cargo.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

local function save(player)
	player:get_meta():set_string(META_KEY, core.write_json(contents(player)))
	for _, fn in ipairs(listeners) do
		fn(player)
	end
end

local function total(player, field)
	local sum = 0
	for name, count in pairs(contents(player)) do
		local def = items[name]
		if def then
			sum = sum + def[field] * count
		end
	end
	return sum
end

function cargo.volume(player)
	return total(player, "volume")
end

function cargo.weight(player)
	return total(player, "weight")
end

function cargo.get(player)
	return table.copy(contents(player))
end

-- Adds as many units as fit; returns how many were added
function cargo.add(player, name, count)
	local def = items[name]
	if not def then
		return 0
	end
	local free = st_machine.stats.get(player).cargo_capacity - cargo.volume(player)
	local fit = math.min(count, math.floor(free / def.volume + 1e-6))
	if fit <= 0 then
		return 0
	end
	local held = contents(player)
	held[name] = (held[name] or 0) + fit
	save(player)
	return fit
end

-- Removes up to count units; returns how many were removed
function cargo.remove(player, name, count)
	local held = contents(player)
	local removed = math.min(count, held[name] or 0)
	if removed <= 0 then
		return 0
	end
	held[name] = held[name] - removed
	if held[name] == 0 then
		held[name] = nil
	end
	save(player)
	return removed
end

function cargo.clear(player)
	cache[player:get_player_name()] = {}
	save(player)
end

function cargo.forget(player)
	cache[player:get_player_name()] = nil
end

st_machine.cargo = cargo
