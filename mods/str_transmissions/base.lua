local transmissions = str_transmissions

str_audio.sfx.register("transmission_ping", {sound = "str_transmissions_ping"})

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

-- text is a space-separated glyph string (see messages.lua); id is optional and marks a book message as received
function transmissions.add(name, text, analysis, id)
	local d = data(name)
	d.unlocked = true
	d.items[#d.items + 1] = {text = text, analysis = analysis, id = id, time = os.time()}
	save(name)
	local player = core.get_player_by_name(name)
	if player then
		str_audio.sfx.play("transmission_ping", {player = player})
		str_utils.show_popup(name, "Unexpected Transmission Received", 4)
	end
end

local book = {}
for _, message in ipairs(dofile(transmissions.modpath .. "/messages.lua")) do
	book[message.id] = message
end

function transmissions.has_received(name, id)
	for _, item in ipairs(data(name).items) do
		if item.id == id then
			return true
		end
	end
	return false
end

-- Sends a message from messages.lua; returns false if the id is unknown or was already received
function transmissions.send(name, id)
	local message = book[id]
	if not message or transmissions.has_received(name, id) then
		return false
	end
	local text = message.text or transmissions.cipher.to_string(transmissions.cipher.noise(message.noise))
	transmissions.add(name, text, message.analysis, id)
	return true
end

-- Hypertext markup drawing a stored glyph string as images, size pixels square
function transmissions.markup(text, size)
	local out = {}
	for n in text:gmatch("%d+") do
		out[#out + 1] = ("<img name=str_transmissions_glyph_%s.png width=%d height=%d>"):format(n, size, size)
	end
	return table.concat(out)
end

function transmissions.reset(name)
	cache[name] = {items = {}}
	save(name)
end

-- Strange object counters per player, kept in mod storage so world resets do not clear them
local relic_cache = {}

local function relic_data(name)
	if not relic_cache[name] then
		local raw = mod_storage:get_string("relics:" .. name)
		local loaded = raw ~= "" and core.parse_json(raw)
		relic_cache[name] = type(loaded) == "table" and loaded or {}
	end
	return relic_cache[name]
end

-- How many strange objects a player digs up before the first transmission, rolled once per player on join
local THRESHOLD_MIN, THRESHOLD_MAX = 10, 20
local thresholds = {}
local deepest = {}

-- Later transmissions: the deepest depth reached (nodes, as on the HUD) and more than this multiple of the
-- player's first threshold in objects dug or destroyed
local LATER = {
	{id = "count_1", depth = 6000, multiple = 2},
	{id = "primes_1", depth = 7000, multiple = 3},
}

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	if meta:get_int("str_transmissions:dlpt") == 0 then
		meta:set_int("str_transmissions:dlpt", math.random(THRESHOLD_MIN, THRESHOLD_MAX))
	end
	local name = player:get_player_name()
	thresholds[name] = meta:get_int("str_transmissions:dlpt")
	deepest[name] = meta:get_int("str_transmissions:deepest")
end)

local function check_triggers(name)
	local threshold = thresholds[name]
	if not threshold then
		return
	end
	local d = relic_data(name)
	local found = (d.dug or 0) + (d.destroyed or 0)
	if found >= threshold then
		transmissions.send(name, "noise_1")
	end
	for _, trigger in ipairs(LATER) do
		if (deepest[name] or 0) >= trigger.depth and found > trigger.multiple * threshold then
			transmissions.send(name, trigger.id)
		end
	end
end

-- kind is "dug", "discarded", "sold" or "destroyed"; does nothing unless item_name is a strange object
function transmissions.count_relic(name, item_name, kind, amount)
	local def = item_name and str_materials.get(item_name)
	if not def or def.kind ~= "relic" then
		return
	end
	local d = relic_data(name)
	d[kind] = (d[kind] or 0) + (amount or 1)
	mod_storage:set_string("relics:" .. name, core.write_json(d))
	check_triggers(name)
end

function transmissions.relic_count(name, kind)
	return relic_data(name)[kind] or 0
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	cache[name] = nil
	relic_cache[name] = nil
	thresholds[name], deepest[name] = nil, nil
end)

str_machine.register_on_dig(function(player, pos, node_name, method)
	local def = core.registered_nodes[node_name]
	transmissions.count_relic(player:get_player_name(), def and def.str_material,
		method == "blast" and "destroyed" or "dug")
end)

str_machine.register_on_depth_change(function(player, depth)
	local name = player:get_player_name()
	if deepest[name] and depth > deepest[name] then
		deepest[name] = depth
		player:get_meta():set_int("str_transmissions:deepest", depth)
		check_triggers(name)
	end
end)
