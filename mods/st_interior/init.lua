st_interior = {}

dofile(core.get_modpath("st_interior") .. "/interact.lua")

-- Every interior node goes through here so they all share the same dig groups
local DIG_GROUPS = {cracky = 1}

-- Footstep sound material per node name; nodes not listed make no footstep sound
local FOOTSTEP_MATERIAL = {}
for material, names in pairs({
	concrete = {
		"shop_floor", "shop_floor_spawn", "shop_wall", "shop_wall_beam",
		"shop_counter", "shop_counter_corner",
	},
	metal = {
		"shop_floor_grate", "shop_ceiling", "shop_ceiling_plain",
		"shop_sink", "shop_drum", "shop_terminal",
		"shop_upgrade_bl", "shop_upgrade_br", "shop_upgrade_tl", "shop_upgrade_tr",
		"shop_refuel_base", "shop_refuel_top", "shop_repair_base", "shop_repair_top",
	},
	wood = {
		"home_floor", "home_wall", "home_ceiling",
		"home_nightstand",
		"home_bookshelf_base", "home_bookshelf_top", "home_wardrobe_base", "home_wardrobe_top",
		"shop_workbench_l", "shop_workbench_r", "shop_crate_large", "shop_crate_small", "shop_shelf",
	},
}) do
	for _, name in ipairs(names) do
		FOOTSTEP_MATERIAL[name] = material
	end
end

local function register_node(name, def)
	def.is_ground_content = false
	local material = FOOTSTEP_MATERIAL[name]
	if material then
		def.sounds = {footstep = {name = "st_interior_footstep_" .. material, gain = 1.0}}
	end
	local groups = table.copy(DIG_GROUPS)
	for group, value in pairs(def.groups or {}) do
		groups[group] = value
	end
	def.groups = groups
	core.register_node("st_interior:" .. name, def)
end
st_interior.register_node = register_node

-- Textures come from tools/gen_interior.py. tiles: top, bottom, sides
local function register(name, description, top, bottom, side)
	register_node(name, {
		description = description,
		tiles = {top .. ".png", bottom .. ".png", side .. ".png"},
	})
end

local function simple(name, description, texture)
	register(name, description, texture, texture, texture)
end

-- 256x256 texture spanning 8 nodes, aligned to the world so neighbours line up
local function world_aligned(name, description, texture, extra)
	local def = {
		description = description,
		tiles = {{name = texture .. ".png", align_style = "world", scale = 8}},
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	register_node(name, def)
end

world_aligned("shop_floor", "Shop floor (concrete)", "st_interior_shop_floor")
-- Marks where the player arrives; facing in param2 (schematics keep it, not metadata)
world_aligned("shop_floor_spawn", "Shop floor (player spawn)", "st_interior_shop_floor", {paramtype2 = "4dir"})
simple("shop_floor_grate", "Shop floor (grate)", "st_interior_shop_floor_grate")
simple("shop_wall", "Shop wall (concrete)", "st_interior_shop_wall")
register("shop_wall_beam", "Shop wall (concrete, steel beam)",
	"st_interior_shop_wall", "st_interior_shop_wall", "st_interior_shop_wall_beam")
register("shop_ceiling", "Shop ceiling (sheet metal, beams)",
	"st_interior_shop_ceiling_plain", "st_interior_shop_ceiling", "st_interior_shop_ceiling_plain")

simple("shop_ceiling_plain", "Shop ceiling (sheet metal, plain)", "st_interior_shop_ceiling_plain")
world_aligned("home_floor", "Home floor (wide planks)", "st_interior_home_floor")
world_aligned("home_wall", "Home wall (painted)", "st_interior_home_wall")
world_aligned("home_ceiling", "Home ceiling (dark boards)", "st_interior_home_ceiling")

-- Roll-down garage door: a slab 1/4 node thick, centred, full width and height. Three nodes stacked:
-- top (roll housing), mid (repeat as needed), bottom (end bar). Shapes and textures from tools/gen_garage.py
-- extra.use = a st_utils.constants.interact kind makes right-click call that kind's listeners
local function register_box(name, description, texture, boxes, extra)
	extra = extra or {}
	local def = {
		description = description,
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		tiles = {
			texture .. "_top.png", texture .. "_bottom.png",
			texture .. "_left.png", texture .. "_right.png",
			texture .. "_back.png", texture .. "_front.png",
		},
		node_box = {type = "fixed", fixed = boxes},
	}
	for k, v in pairs(extra) do
		def[k] = v
	end
	if extra.use then
		def.use = nil
		def.use_kind = extra.use
		def.on_rightclick = st_interior.make_on_rightclick(extra.use)
	end
	register_node(name, def)
end
st_interior.register_box = register_box

register_box("garage_door_top", "Garage door (top, housing)", "st_interior_garage_door_top", {
	{-16/32, -16/32, -4/32, 16/32, 10/32, 4/32},
	{-16/32, 10/32, -8/32, 16/32, 16/32, 8/32},
})
register_box("garage_door_mid", "Garage door (middle)", "st_interior_garage_door_mid", {
	{-16/32, -16/32, -4/32, 16/32, 16/32, 4/32},
})
register_box("garage_door_bottom", "Garage door (bottom, bar)", "st_interior_garage_door_bottom", {
	{-16/32, -13/32, -4/32, 16/32, 16/32, 4/32},
	{-16/32, -16/32, -6/32, 16/32, -13/32, 6/32},
})

-- Window: the same thin slab, a white frame around a bright pane. Opaque to the eye but daylight
-- passes through it (nodebox + paramtype light), no light of its own. 4 turns around Y only like
-- the digger display (tools/gen_window.py)
register_box("window", "Window", "st_interior_window", {
	{-16/32, -16/32, -4/32, 16/32, 16/32, 4/32},
}, {paramtype2 = "4dir"})

dofile(core.get_modpath("st_interior") .. "/door.lua")
dofile(core.get_modpath("st_interior") .. "/lamp.lua")
dofile(core.get_modpath("st_interior") .. "/furniture.lua")
dofile(core.get_modpath("st_interior") .. "/home.lua")
dofile(core.get_modpath("st_interior") .. "/tools.lua")

-- Display-only digger: an invisible selectable node owns a scaled entity (st_machine's mesh)
local DIGGER_SCALE = 7
local DIGGER_HALF_X = 0.4375 * DIGGER_SCALE
local DIGGER_HALF_Z = 0.391 * DIGGER_SCALE
-- The mesh sits at x = -0.375..0.5, y = -0.5..-0.047 around its origin
local DIGGER_CENTER_X = 0.0625 * DIGGER_SCALE
local DIGGER_ORIGIN_Y = 0.5 * DIGGER_SCALE - 0.5
local DIGGER_ENTITY = "st_interior:digger_display"
-- Live display entities, so a color change reaches them
local display_entities = {}

local function apply_player_colors(self)
	local player = core.get_connected_players()[1]
	if player then
		self.object:set_properties({textures = st_machine.model_textures(player)})
	end
end

core.register_entity(DIGGER_ENTITY, {
	initial_properties = {
		visual = "mesh",
		mesh = "digger1.glb",
		visual_size = vector.new(10, 10, 9) * DIGGER_SCALE,
		textures = st_machine.model_textures(),
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

st_machine.register_on_colors_changed(function(_, textures)
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
	if core.get_node(pos).name ~= "st_interior:digger_display" then
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

st_interior.ensure_digger_entity = ensure_digger_entity

core.register_node("st_interior:digger_display", {
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
	groups = {cracky = 1},
	use_kind = st_utils.constants.interact.drive,
	on_rightclick = st_interior.make_on_rightclick(st_utils.constants.interact.drive),
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
	name = "st_interior:digger_display_entity",
	nodenames = {"st_interior:digger_display"},
	run_at_every_load = true,
	action = function(pos)
		if not delayed[core.hash_node_position(pos)] then
			ensure_digger_entity(pos, 5)
		end
	end,
})
