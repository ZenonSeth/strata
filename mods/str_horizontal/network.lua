-- One waypoint per x column, in mod storage: {y = y of the node, name = text}
local storage = core.get_mod_storage()

-- Nodes between two waypoints along x
str_horizontal.MIN_DISTANCE = 100

local function key(x)
	return "wp:" .. x
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

-- Whether any waypoint is closer than distance to x (the column x itself counts)
function str_horizontal.within(x, distance)
	for field in pairs(storage:to_table().fields) do
		local other = tonumber(field:match("^wp:(.+)$"))
		if other and math.abs(other - x) < distance and storage:get_string(field) ~= "" then
			return true
		end
	end
	return false
end

-- Every waypoint: {x =, y =, name =}
function str_horizontal.all()
	local list = {}
	for field in pairs(storage:to_table().fields) do
		local x = tonumber(field:match("^wp:(.+)$"))
		local wp = x and str_horizontal.get(x)
		if wp then
			list[#list + 1] = {x = x, y = wp.y, name = wp.name}
		end
	end
	table.sort(list, function(a, b) return a.x < b.x end)
	return list
end
