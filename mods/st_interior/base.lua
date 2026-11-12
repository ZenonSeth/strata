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
	core.register_node("st_interior:" .. name, def)
end
st_interior.register_node = register_node

-- tiles: top, bottom, sides
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
-- top (roll housing), mid (repeat as needed), bottom (end bar).
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
-- the digger display
register_box("window", "Window", "st_interior_window", {
	{-16/32, -16/32, -4/32, 16/32, 16/32, 4/32},
}, {paramtype2 = "4dir"})
