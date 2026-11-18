-- One waypoint per x column, in mod storage: {y = y of the node, name = text, owner = player name}
-- Older saves have no owner; the first player to open the waypoint claims it
local storage = core.get_mod_storage()

-- Nodes between two waypoints along x
str_horizontal.MIN_DISTANCE = 100

-- x rounded from just below 0 is -0, which must share the column's key with 0
local function key(x)
	return "wp:" .. (x == 0 and 0 or x)
end

-- Older saves may hold a column under a non-canonical key ("wp:-0")
for _, field in ipairs(storage:get_keys()) do
	local x = tonumber(field:match("^wp:(.+)$"))
	if x and key(x) ~= field then
		local raw = storage:get_string(field)
		if storage:get_string(key(x)) == "" then
			storage:set_string(key(x), raw)
		else
			core.log("warning", ("str_horizontal: dropped duplicate waypoint %s: %s"):format(field, raw))
		end
		storage:set_string(field, "")
	end
end

function str_horizontal.get(x)
	local raw = storage:get_string(key(x))
	return raw ~= "" and core.parse_json(raw) or nil
end

-- A nil waypoint deletes it
function str_horizontal.save(x, wp)
	storage:set_string(key(x), wp and core.write_json(wp) or "")
end

-- Next number for default names
function str_horizontal.next_number()
	local n = storage:get_int("counter") + 1
	storage:set_int("counter", n)
	return n
end

-- Whether a waypoint of owner (or an unowned one) is closer than distance to x
function str_horizontal.within(x, distance, owner)
	for field in pairs(storage:to_table().fields) do
		local other = tonumber(field:match("^wp:(.+)$"))
		if other and math.abs(other - x) < distance then
			local wp = str_horizontal.get(other)
			if wp and (not wp.owner or wp.owner == owner) then
				return true
			end
		end
	end
	return false
end

-- One setting per player for all their waypoints; public by default
function str_horizontal.is_private(player_name)
	return storage:get_string("private:" .. player_name) == "1"
end

function str_horizontal.set_private(player_name, private)
	storage:set_string("private:" .. player_name, private and "1" or "")
end

-- Every waypoint: {x =, y =, name =, owner =}
function str_horizontal.all()
	local list = {}
	for field in pairs(storage:to_table().fields) do
		local x = tonumber(field:match("^wp:(.+)$"))
		local wp = x and str_horizontal.get(x)
		if wp then
			list[#list + 1] = {x = x, y = wp.y, name = wp.name, owner = wp.owner}
		end
	end
	table.sort(list, function(a, b) return a.x < b.x end)
	return list
end
