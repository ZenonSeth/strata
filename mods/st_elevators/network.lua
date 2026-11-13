-- One network per x column, in mod storage: {top = y of the surface station, stops = {{y =, name =}, ...}, counter = n}
local storage = core.get_mod_storage()

-- Nodes between a stop and every other stop or the surface station
st_elevators.MIN_DISTANCE = 250
-- Nodes between two surface stations along x
st_elevators.MIN_X_DISTANCE = 200

local function key(x)
	return "net:" .. x
end

function st_elevators.get_network(x)
	local raw = storage:get_string(key(x))
	local net = raw ~= "" and core.parse_json(raw) or nil
	if net then
		net.stops = net.stops or {}
	end
	return net
end

-- A nil network deletes it
function st_elevators.save_network(x, net)
	storage:set_string(key(x), net and core.write_json(net) or "")
end

-- Whether another network's column is closer than distance to x (the column x itself counts)
function st_elevators.network_within(x, distance)
	for field in pairs(storage:to_table().fields) do
		local other = tonumber(field:match("^net:(.+)$"))
		if other and math.abs(other - x) < distance and storage:get_string(field) ~= "" then
			return true
		end
	end
	return false
end

function st_elevators.stop_index(net, y)
	for i, stop in ipairs(net.stops) do
		if stop.y == y then
			return i
		end
	end
end

-- Every place the network reaches, highest first: {y =, name =, surface = bool}
function st_elevators.destinations(net)
	local list = {{y = net.top, name = "Surface", surface = true}}
	for _, stop in ipairs(net.stops) do
		list[#list + 1] = {y = stop.y, name = stop.name}
	end
	table.sort(list, function(a, b) return a.y > b.y end)
	return list
end
