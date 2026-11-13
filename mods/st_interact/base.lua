-- id -> {label = prompt shown while the machine is in front of it, on_use = function(player, pos)}
local handlers = {}

-- A node opts in with an `st_interact = id` field in its definition
function st_interact.register(id, def)
	assert(type(id) == "string" and not handlers[id], "st_interact: bad or duplicate id " .. tostring(id))
	assert(type(def.label) == "string" and type(def.on_use) == "function", "st_interact: " .. id .. " needs a label and on_use")
	handlers[id] = def
end

-- Handler of the node at pos, or nil if it is not interactable
function st_interact.get(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def and def.st_interact and handlers[def.st_interact]
end
