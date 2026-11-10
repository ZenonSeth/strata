local storage = st_storage

local META_KEY = "st_storage:contents"
local capacity = st_utils.constants.storage_capacity

local cache = {}
local listeners = {}

local function contents(player)
	local name = player:get_player_name()
	if not cache[name] then
		local raw = player:get_meta():get_string(META_KEY)
		local data = raw ~= "" and core.parse_json(raw)
		cache[name] = type(data) == "table" and data or {}
	end
	return cache[name]
end

local function save(player)
	player:get_meta():set_string(META_KEY, core.write_json(contents(player)))
	for _, fn in ipairs(listeners) do
		fn(player)
	end
end

-- fn(player) runs after the storage contents change
function storage.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

function storage.get(player)
	return table.copy(contents(player))
end

function storage.volume(player)
	local sum = 0
	for name, count in pairs(contents(player)) do
		local def = st_materials.get(name)
		if def then
			sum = sum + def.volume * count
		end
	end
	return sum
end

function storage.free_volume(player)
	return math.max(capacity - storage.volume(player), 0)
end

-- Adds as many units as fit; returns how many were added
function storage.add(player, name, count)
	local def = st_materials.get(name)
	if not def then
		return 0
	end
	local fit = math.min(count, math.floor(storage.free_volume(player) / def.volume + 1e-6))
	if fit <= 0 then
		return 0
	end
	local held = contents(player)
	held[name] = (held[name] or 0) + fit
	save(player)
	return fit
end

-- Removes up to count units; returns how many were removed
function storage.remove(player, name, count)
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

-- Moves as many units as fit from the hold into storage; returns how many moved
function storage.deposit(player, name, count)
	local cargo = st_machine.cargo
	local added = storage.add(player, name, math.min(count, cargo.get(player)[name] or 0))
	if added > 0 then
		cargo.remove(player, name, added)
	end
	return added
end

-- Moves as many units as fit from storage into the hold; returns how many moved
function storage.withdraw(player, name, count)
	local taken = storage.remove(player, name, count)
	if taken <= 0 then
		return 0
	end
	local added = st_machine.cargo.add(player, name, taken)
	if added < taken then
		storage.add(player, name, taken - added)
	end
	return added
end

-- Moves as much of the cargo hold as fits; returns the volume moved
function storage.deposit_all(player)
	local moved = 0
	for name, count in pairs(st_machine.cargo.get(player)) do
		moved = moved + storage.deposit(player, name, count) * st_materials.get(name).volume
	end
	return moved
end

function storage.withdraw_all(player)
	local moved = 0
	for name, count in pairs(storage.get(player)) do
		moved = moved + storage.withdraw(player, name, count) * st_materials.get(name).volume
	end
	return moved
end

core.register_on_leaveplayer(function(player)
	cache[player:get_player_name()] = nil
end)
