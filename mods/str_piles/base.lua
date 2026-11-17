local COUNT_KEY = "count"
-- A low mound hugging the backing wall (+z side of the cell)
local MOUND = {type = "fixed", fixed = {
	{-0.45, -0.5, 0.1, 0.45, -0.2, 0.5},
	{-0.3, -0.2, 0.2, 0.3, 0.05, 0.5},
}}
-- Gems: a stepped pyramid of three tiers
local STACK = {type = "fixed", fixed = {
	{-0.4, -0.5, 0.1, 0.4, -0.25, 0.5},
	{-0.28, -0.25, 0.2, 0.28, 0, 0.5},
	{-0.14, 0, 0.3, 0.14, 0.25, 0.5},
}}

for _, item in ipairs(str_materials.list) do
	if item.kind == "ore" or item.kind == "gem" then
		core.register_node("str_piles:" .. item.name, {
			description = item.description .. " pile",
			drawtype = "nodebox",
			node_box = item.kind == "gem" and STACK or MOUND,
			tiles = {item.icon},
			use_texture_alpha = "clip",
			paramtype = "light",
			sunlight_propagates = true,
			walkable = false,
			pointable = false,
			diggable = false,
			buildable_to = false,
			is_ground_content = false,
			drop = "",
			groups = str_utils.get_common_groups({not_in_creative_inventory = 1}),
			str_pile_item = item.name,
		})
	end
end

-- Leaves count units of item as a pile at pos (a cell just emptied by digging); false if it has no pile
function str_piles.drop(pos, item, count)
	local name = "str_piles:" .. item
	if count <= 0 or not core.registered_nodes[name] then
		return false
	end
	core.set_node(pos, {name = name})
	core.get_meta(pos):set_int(COUNT_KEY, count)
	return true
end

-- Item and unit count of the pile at pos, or nil if there is none
function str_piles.get(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	if def and def.str_pile_item then
		return def.str_pile_item, core.get_meta(pos):get_int(COUNT_KEY)
	end
end

-- Moves as much of the pile at pos as add(item, count) -> taken accepts; removes it once empty
function str_piles.collect(pos, add)
	local def = core.registered_nodes[core.get_node(pos).name]
	local item = def and def.str_pile_item
	if not item then
		return
	end
	local meta = core.get_meta(pos)
	local left = meta:get_int(COUNT_KEY)
	left = left - add(item, left)
	if left <= 0 then
		core.remove_node(pos)
		str_nodes.refresh_shapes(pos)
	else
		meta:set_int(COUNT_KEY, left)
	end
end
