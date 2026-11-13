-- Display-only digger: an invisible selectable node owns a scaled entity (str_machine's mesh)
local DIGGER_SCALE = 7
local DIGGER_HALF_X = 0.4375 * DIGGER_SCALE
local DIGGER_HALF_Z = 0.391 * DIGGER_SCALE
-- The mesh sits at x = -0.375..0.5, y = -0.5..-0.047 around its origin
local DIGGER_CENTER_X = 0.0625 * DIGGER_SCALE
local DIGGER_ORIGIN_Y = 0.5 * DIGGER_SCALE - 0.5
local DIGGER_ENTITY = "str_interior:digger_display"
-- Live display entities, so a color change reaches them
local display_entities = {}

local function apply_player_colors(self)
	local player = core.get_connected_players()[1]
	if player then
		self.object:set_properties({textures = str_machine.model_textures(player)})
	end
end

core.register_entity(DIGGER_ENTITY, {
	initial_properties = {
		visual = "mesh",
		mesh = "digger1.glb",
		visual_size = vector.new(10, 10, 9) * DIGGER_SCALE,
		textures = str_machine.model_textures(),
		physical = false,
		pointable = false,
		static_save = false,
	},
	keep_on_clear = true,
	on_activate = function(self)
		display_entities[self] = true
		apply_player_colors(self)
	end,
	on_deactivate = function(self)
		display_entities[self] = nil
	end,
})

str_machine.register_on_colors_changed(function(_, textures)
	for self in pairs(display_entities) do
		self.object:set_properties({textures = textures})
	end
end)

-- Entity pos and yaw that put the mesh centred on the node, wheels on the node's bottom face
local function digger_placement(pos)
	local yaw = core.get_node(pos).param2 * math.pi / 2
	local offset = vector.rotate(vector.new(-DIGGER_CENTER_X, DIGGER_ORIGIN_Y, 0), vector.new(0, yaw, 0))
	return vector.add(pos, offset), yaw
end

local function find_digger_entities(entity_pos)
	local found = {}
	for _, obj in ipairs(core.get_objects_inside_radius(entity_pos, 0.5)) do
		local entity = obj:get_luaentity()
		if entity and entity.name == DIGGER_ENTITY then
			found[#found + 1] = obj
		end
	end
	return found
end

-- Hashes of nodes whose entity is waiting for a delayed spawn; the LBM leaves those to the delay
local delayed = {}

local function spawn_digger_entity(pos, attempts)
	delayed[core.hash_node_position(pos)] = nil
	if core.get_node(pos).name ~= "str_interior:digger_display" then
		return -- removed or unloaded meanwhile; the LBM brings it back on load
	end
	local entity_pos, yaw = digger_placement(pos)
	if #find_digger_entities(entity_pos) > 0 then
		return
	end
	local obj = core.add_entity(entity_pos, DIGGER_ENTITY)
	if obj then
		obj:set_yaw(yaw)
	elseif attempts > 1 then
		core.after(1, spawn_digger_entity, pos, attempts - 1)
	end
end

-- delay (seconds) is optional: without it the entity spawns at once
local function ensure_digger_entity(pos, attempts, delay)
	if delay and delay > 0 then
		delayed[core.hash_node_position(pos)] = true
		core.after(delay, spawn_digger_entity, pos, attempts)
	else
		spawn_digger_entity(pos, attempts)
	end
end

str_interior.ensure_digger_entity = ensure_digger_entity

core.register_node("str_interior:digger_display", {
	description = "Digger (display model)",
	drawtype = "airlike",
	inventory_image = "[fill:16x16:#c04040",
	paramtype = "light",
	paramtype2 = "4dir",
	sunlight_propagates = true,
	pointable = true,
	walkable = false,
	is_ground_content = false,
	selection_box = {type = "fixed", fixed = {
		-DIGGER_HALF_X, -0.5, -DIGGER_HALF_Z,
		DIGGER_HALF_X, -0.5 + 0.44 * DIGGER_SCALE, DIGGER_HALF_Z,
	}},
	use_kind = str_utils.constants.interact.drive,
	on_rightclick = str_interior.make_on_rightclick(str_utils.constants.interact.drive),
	on_construct = function(pos)
		ensure_digger_entity(pos, 5)
	end,
	on_destruct = function(pos)
		for _, obj in ipairs(find_digger_entities((digger_placement(pos)))) do
			obj:remove()
		end
	end,
})

-- The entity is not saved, so bring it back whenever the node's block loads
core.register_lbm({
	name = "str_interior:digger_display_entity",
	nodenames = {"str_interior:digger_display"},
	run_at_every_load = true,
	action = function(pos)
		if not delayed[core.hash_node_position(pos)] then
			ensure_digger_entity(pos, 5)
		end
	end,
})
