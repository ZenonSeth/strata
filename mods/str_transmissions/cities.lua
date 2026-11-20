-- Cities owed: after story.cities.start, relics placed back or cities built behind the machine pay them off
local transmissions = str_transmissions
local cities = {}
transmissions.cities = cities

local CITIES = transmissions.story.cities
local SLICE_Z = str_utils.constants.slice_z
local SURFACE_Y = str_utils.constants.surface_y
-- The backing wall's param2: the darker palette entry (str_worldgen terrain.lua BACK_PARAM2)
local BACK_PARAM2 = 255
local nodes = str_nodes.data
local mod_storage = transmissions.mod_storage

-- Shallowest depth any strange object occurs at
local MIN_DEPTH
for _, g in ipairs(nodes.gems) do
	if g.relic then
		for _, point in ipairs(g.curve) do
			if point[2] > 0 then
				MIN_DEPTH = math.min(MIN_DEPTH or point[1], point[1])
				break
			end
		end
	end
end

local cache = {}

local function key(name)
	return "cities:" .. name
end

-- {owed = cities still owed (nil before the start signal), build = building allowed, warned, done, placed, built}
local function state(name)
	if not cache[name] then
		local raw = mod_storage:get_string(key(name))
		local loaded = raw ~= "" and core.parse_json(raw)
		cache[name] = type(loaded) == "table" and loaded or {}
	end
	return cache[name]
end

local function save(name)
	mod_storage:set_string(key(name), core.write_json(state(name)))
	transmissions.notify_change(name)
end

function cities.reset(name)
	cache[name] = nil
	mod_storage:set_string(key(name), "")
end

local function active(c)
	return c.owed ~= nil and not c.done
end

-- Cities still owed, or nil when none are asked for
function cities.owed(name)
	local c = state(name)
	return active(c) and c.owed or nil
end

function cities.can_place(name)
	return active(state(name))
end

function cities.can_build(name)
	local c = state(name)
	return active(c) and c.build == true
end

local function relics_held(player)
	local count = 0
	for _, store in ipairs({str_machine.cargo, str_storage}) do
		for item, n in pairs(store.get(player)) do
			local def = str_materials.get(item)
			if def and def.kind == "relic" then
				count = count + n
			end
		end
	end
	return count
end

-- True when the relics in hold and storage cannot pay off the cities owed
function cities.is_gone(name)
	local c = state(name)
	local player = core.get_player_by_name(name)
	return active(c) and player ~= nil and relics_held(player) < c.owed
end

-- {item, count} pairs a built city takes from the hold, in a fixed order
function cities.build_cost()
	local list = {}
	for item, count in pairs(CITIES.build_cost) do
		list[#list + 1] = {item = item, count = count}
	end
	table.sort(list, function(a, b) return a.item < b.item end)
	return list
end

function cities.has_build_cost(player)
	local held = str_machine.cargo.get(player)
	for _, cost in ipairs(cities.build_cost()) do
		if (held[cost.item] or 0) < cost.count then
			return false
		end
	end
	return true
end

-- Backing rock node name -> its stratum, built once every node is registered
local host_of

local function backing_host(node_name)
	if not host_of then
		host_of = {}
		for _, s in ipairs(nodes.strata) do
			host_of["str_nodes:" .. s.name] = s.name
			host_of[nodes.hot_node(s.name)] = s.name
		end
		for name, def in pairs(core.registered_nodes) do
			if def.str_base and host_of[def.str_base] then
				host_of[name] = host_of[def.str_base]
			end
		end
	end
	return host_of[node_name]
end

-- Backing cell behind the machine and its stratum, or nil and the reason it cannot take a city
local function target(player)
	local pos = str_mode.get(player) == "vehicle" and str_machine.get_pos(player)
	if not pos then
		return nil, "Get in the digger first."
	end
	pos = vector.round(vector.new(pos.x, pos.y, SLICE_Z + 1))
	if SURFACE_Y - pos.y < MIN_DEPTH then
		return nil, ("Cities only hold in the stone below %d m."):format(MIN_DEPTH)
	end
	local host = backing_host(core.get_node(pos).name)
	if not host then
		return nil, "There is no bare stone behind the digger."
	end
	return pos, host
end

-- Pays off one city; returns the result line
local function settle(name, kind)
	local c = state(name)
	c.owed = c.owed - 1
	c[kind] = (c[kind] or 0) + 1
	if c.owed <= 0 then
		c.done = true
	end
	save(name)
	if c.done then
		transmissions.send_soon(name, CITIES.done)
		return "The last city is back in the stone."
	end
	return ("City %s. Cities still owed: %d."):format(kind == "built" and "built" or "placed back", c.owed)
end

-- Puts the selected strange object back in the stone; returns the result line, or nil if it is not allowed
function cities.place(player, item)
	local name = player:get_player_name()
	local def = str_materials.get(item)
	if not cities.can_place(name) or not def or def.kind ~= "relic" then
		return nil
	end
	local pos, host = target(player)
	if not pos then
		return host
	end
	if str_machine.cargo.remove(player, item, 1) < 1 then
		return nil
	end
	core.set_node(pos, {name = nodes.gem_node(item, host), param2 = BACK_PARAM2})
	transmissions.count_relic(name, item, "placed")
	return settle(name, "placed")
end

-- Builds a new city from the hold; returns the result line, or nil if it is not allowed or affordable
function cities.build(player)
	local name = player:get_player_name()
	if not cities.can_build(name) or not cities.has_build_cost(player) then
		return nil
	end
	local pos, host = target(player)
	if not pos then
		return host
	end
	for _, cost in ipairs(cities.build_cost()) do
		str_machine.cargo.remove(player, cost.item, cost.count)
	end
	local variants = CITIES.build_variants
	core.set_node(pos, {name = nodes.gem_node(variants[math.random(#variants)], host), param2 = BACK_PARAM2})
	return settle(name, "built")
end

transmissions.register_on_receive(function(name, id)
	local c = state(name)
	if id == CITIES.start and c.owed == nil then
		c.owed = CITIES.owed
		save(name)
	elseif id == CITIES.build and not c.build then
		c.build = true
		save(name)
	end
end)

transmissions.register_on_relic(function(name, kind, amount)
	local c = state(name)
	local add = CITIES.add[kind]
	if not add or not active(c) or amount <= 0 then
		return
	end
	c.owed = c.owed + add * amount
	local first = not c.warned
	c.warned = true
	save(name)
	if first then
		transmissions.send_soon(name, CITIES.warning)
	end
end)

core.register_on_leaveplayer(function(player)
	cache[player:get_player_name()] = nil
end)
