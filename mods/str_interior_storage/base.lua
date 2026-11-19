local storage = core.get_mod_storage()
local GROUP = str_groups.SAVED_STATE

-- MIGRATIONS[n](nodes) returns layout n's nodes table for layout n + 1; add one when a shop_home.mts edit moves state nodes
local MIGRATIONS = {}
local VERSION = #MIGRATIONS + 1

-- Mod storage "nodes:<player name>": JSON {v = layout version, nodes = {"x,y,z" (relative to the origin) -> {name}}}
local function storage_key(player_name)
	return "nodes:" .. player_name
end

-- The saved nodes in the current layout, and whether a migration changed them
local function load_saved(player_name)
	local raw = storage:get_string(storage_key(player_name))
	local data = raw ~= "" and core.parse_json(raw) or nil
	local v = type(data) == "table" and tonumber(data.v)
	if not (v and type(data.nodes) == "table") then
		return {}, false
	end
	local nodes = data.nodes
	for n = v, VERSION - 1 do
		nodes = MIGRATIONS[n](nodes)
	end
	return nodes, v < VERSION
end

local function store(player_name, nodes)
	storage:set_string(storage_key(player_name), next(nodes) and core.write_json({v = VERSION, nodes = nodes}) or "")
end

-- Names of all players with saved interior state
function str_interior_storage.saved_players()
	local names = {}
	for _, key in ipairs(storage:get_keys()) do
		local name = key:match("^nodes:(.+)$")
		if name then
			names[#names + 1] = name
		end
	end
	return names
end

function str_interior_storage.clear(player_name)
	storage:set_string(storage_key(player_name), "")
end

-- Whether any saved entry is a real change (its node sets _str_state_dirty), not just e.g. a door's state
function str_interior_storage.is_dirty(player_name)
	for _, entry in pairs((load_saved(player_name))) do
		local def = type(entry) == "table" and type(entry.name) == "string" and core.registered_nodes[entry.name]
		if def and def._str_state_dirty == true then
			return true
		end
	end
	return false
end

local function pos_key(rel)
	return rel.x .. "," .. rel.y .. "," .. rel.z
end

-- A saved name restores only onto a node of the same family (e.g. the same door half); nil if not in the group
local function family(name)
	if type(name) == "string" and core.get_item_group(name, GROUP) > 0 then
		return core.registered_nodes[name]._str_state_family or name
	end
end

str_interior.register_on_state_change(function(pos, node)
	local owner, origin = str_start.owner_at(pos)
	if not owner then
		return
	end
	local nodes = load_saved(owner)
	nodes[pos_key(vector.subtract(vector.round(pos), origin))] = {name = node.name}
	store(owner, nodes)
end)

-- The rotation stays as the schematic places it; entries whose spot no longer holds their family are dropped
str_start.register_on_interior_placed(function(player_name, origin)
	local nodes, changed = load_saved(player_name)
	for key, entry in pairs(nodes) do
		local x, y, z = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
		local name = type(entry) == "table" and entry.name
		local pos = x and vector.offset(origin, tonumber(x), tonumber(y), tonumber(z))
		local current = pos and core.get_node(pos)
		local saved_family = family(name)
		if current and saved_family and saved_family == family(current.name) then
			if current.name ~= name then
				core.swap_node(pos, {name = name, param2 = current.param2})
			end
		else
			nodes[key], changed = nil, true
		end
	end
	if changed then
		store(player_name, nodes)
	end
end)
