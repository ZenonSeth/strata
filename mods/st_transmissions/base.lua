local transmissions = st_transmissions

local mod_storage = core.get_mod_storage()
local cache = {}
local listeners = {}

local function key(name)
	return "transmissions:" .. name
end

local function data(name)
	if not cache[name] then
		local raw = mod_storage:get_string(key(name))
		local loaded = raw ~= "" and core.parse_json(raw)
		cache[name] = type(loaded) == "table" and loaded or {}
		cache[name].items = cache[name].items or {}
	end
	return cache[name]
end

local function save(name)
	mod_storage:set_string(key(name), core.write_json(data(name)))
	local player = core.get_player_by_name(name)
	if player then
		for _, fn in ipairs(listeners) do
			fn(player)
		end
	end
end

-- fn(player) runs after a player's transmissions change
function transmissions.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

function transmissions.is_unlocked(player)
	return data(player:get_player_name()).unlocked == true
end

-- Makes the Transmissions tab appear; receiving a transmission does this too
function transmissions.unlock(name)
	local d = data(name)
	if not d.unlocked then
		d.unlocked = true
		save(name)
	end
end

-- Oldest first; each is {text = glyph string, analysis = plain machine line, time = os.time()}
function transmissions.get(name)
	return table.copy(data(name).items)
end

function transmissions.add(name, text, analysis)
	local d = data(name)
	d.unlocked = true
	d.items[#d.items + 1] = {text = text, analysis = analysis, time = os.time()}
	save(name)
end

function transmissions.reset(name)
	cache[name] = {items = {}}
	save(name)
end

core.register_on_leaveplayer(function(player)
	cache[player:get_player_name()] = nil
end)

-- TODO: count relics and other nodes (see "The mystery" in digmachine_world_economy.md); method is "drill", "blast", ...
st_machine.register_on_dig(function(player, pos, node_name, method)
end)

-- TODO: track deepest depth and pick transmissions by depth (see "The mystery" in digmachine_world_economy.md)
st_machine.register_on_depth_change(function(player, depth, old_depth)
end)
