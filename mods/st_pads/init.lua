st_pads = {}

local TEXTURE = "st_nodes_metal_plate.png"

-- pad id -> {label = string, on_use = function(player)}
local pads = {}

local function register_node(name, description, extra)
	local def = {
		description = description,
		tiles = {TEXTURE},
		groups = {not_in_creative_inventory = 1},
		diggable = false,
		is_ground_content = false,
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	-- The ":" prefix lets other mods register their pads under st_pads:
	core.register_node(":" .. name, def)
end

-- Same look as an active pad, no action
register_node("st_pads:pad", "Pad")

-- def: {label = prompt shown while the machine stands on it, on_use = function(player)}
function st_pads.register(id, def)
	pads[id] = def
	register_node("st_pads:pad_" .. id, "Pad (" .. id .. ")", {st_pad = id})
end

-- Pad definition of the node at pos, or nil if it is not an active pad
function st_pads.get(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def and def.st_pad and pads[def.st_pad]
end
