-- One network per x column, in mod storage:
-- {top = y of the surface station, stops = {{y =, name =, owner =}, ...}, counter = n, owner =, private = bool}
-- Older saves have no owners; the first player to open a station claims them
local storage = core.get_mod_storage()

-- Nodes between a stop and every other stop or the surface station
str_elevators.MIN_DISTANCE = 250
-- Nodes between two surface stations along x
str_elevators.MIN_X_DISTANCE = 200

local function key(x)
	return "net:" .. x
end

function str_elevators.get_network(x)
	local raw = storage:get_string(key(x))
	local net = raw ~= "" and core.parse_json(raw) or nil
	if net then
		net.stops = net.stops or {}
	end
	return net
end

-- A nil network deletes it
function str_elevators.save_network(x, net)
	storage:set_string(key(x), net and core.write_json(net) or "")
end

-- Whether a network of owner (or an unowned one) has its column closer than distance to x
function str_elevators.network_within(x, distance, owner)
	for field in pairs(storage:to_table().fields) do
		local other = tonumber(field:match("^net:(.+)$"))
		if other and math.abs(other - x) < distance then
			local net = str_elevators.get_network(other)
			if net and (not net.owner or net.owner == owner) then
				return true
			end
		end
	end
	return false
end

-- Every network: {x =, net =}
function str_elevators.all()
	local list = {}
	for field in pairs(storage:to_table().fields) do
		local x = tonumber(field:match("^net:(.+)$"))
		local net = x and str_elevators.get_network(x)
		if net then
			list[#list + 1] = {x = x, net = net}
		end
	end
	return list
end

function str_elevators.stop_index(net, y)
	for i, stop in ipairs(net.stops) do
		if stop.y == y then
			return i
		end
	end
end

-- Every place the network reaches, highest first: {y =, name =, surface = bool}
function str_elevators.destinations(net)
	local list = {{y = net.top, name = "Surface", surface = true}}
	for _, stop in ipairs(net.stops) do
		list[#list + 1] = {y = stop.y, name = stop.name}
	end
	table.sort(list, function(a, b) return a.y > b.y end)
	return list
end
