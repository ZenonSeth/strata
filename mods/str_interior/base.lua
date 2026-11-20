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
	if def.pointable == nil and not def.on_rightclick then
		def.pointable = "blocking"
		def.groups = table.copy(def.groups or {})
		def.groups[str_groups.BLOCKING] = 1
	end
	local material = FOOTSTEP_MATERIAL[name]
	if material then
		def.sounds = {footstep = {name = "str_interior_footstep_" .. material, gain = 1.0}}
	end
	core.register_node("str_interior:" .. name, def)
end
str_interior.register_node = register_node

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

local FLOOR = {groups = {[str_groups.FLOOR] = 1}}
world_aligned("shop_floor", "Shop floor (concrete)", "str_interior_shop_floor", FLOOR)
-- Marks where the player arrives; facing in param2 (schematics keep it, not metadata)
world_aligned("shop_floor_spawn", "Shop floor (player spawn)", "str_interior_shop_floor", {paramtype2 = "4dir"})
-- Grate: dark inner cube 1/16 in, a 1/16 deep shell of bars around it with 4x4 holes per face.
-- The texture paints the same holes dark; boxes do not overlap, so no z-fighting.
local function grate_boxes()
	local cuts = {0, 2, 6, 10, 14, 18, 22, 26, 30, 32}
	local n = #cuts - 1
	local function shell(i) return i == 1 or i == n end
	local function hole(i) return i % 2 == 0 end
	local function solid(c)
		for a = 1, 3 do
			if shell(c[a]) and hole(c[a % 3 + 1]) and hole(c[(a + 1) % 3 + 1]) then
				return false
			end
		end
		return shell(c[1]) or shell(c[2]) or shell(c[3])
	end
	local used = {}
	local function free(x, y, z)
		return not used[(z * 16 + y) * 16 + x] and solid({x, y, z})
	end
	local function px(i) return cuts[i] / 32 - 0.5 end
	local boxes = {{-7/16, -7/16, -7/16, 7/16, 7/16, 7/16}}
	for z = 1, n do for y = 1, n do for x = 1, n do
		if free(x, y, z) then
			local x2, y2, z2 = x, y, z
			while x2 < n and free(x2 + 1, y, z) do x2 = x2 + 1 end
			local function row_free(yy, zz)
				for xx = x, x2 do
					if not free(xx, yy, zz) then return false end
				end
				return true
			end
			while y2 < n and row_free(y2 + 1, z) do y2 = y2 + 1 end
			local function layer_free(zz)
				for yy = y, y2 do
					if not row_free(yy, zz) then return false end
				end
				return true
			end
			while z2 < n and layer_free(z2 + 1) do z2 = z2 + 1 end
			for zz = z, z2 do for yy = y, y2 do for xx = x, x2 do
				used[(zz * 16 + yy) * 16 + xx] = true
			end end end
			boxes[#boxes + 1] = {px(x), px(y), px(z), px(x2 + 1), px(y2 + 1), px(z2 + 1)}
		end
	end end end
	return boxes
end
register_node("shop_floor_grate", {
	description = "Shop floor (grate)",
	drawtype = "nodebox",
	tiles = {"str_interior_shop_floor_grate.png"},
	node_box = {type = "fixed", fixed = grate_boxes()},
	groups = {[str_groups.FLOOR] = 1},
	collision_box = {type = "regular"},
	selection_box = {type = "regular"},
})
simple("shop_wall", "Shop wall (concrete)", "str_interior_shop_wall")
register("shop_wall_beam", "Shop wall (concrete, steel beam)",
	"str_interior_shop_wall", "str_interior_shop_wall", "str_interior_shop_wall_beam")
register("shop_ceiling", "Shop ceiling (sheet metal, beams)",
	"str_interior_shop_ceiling_plain", "str_interior_shop_ceiling", "str_interior_shop_ceiling_plain")

simple("shop_ceiling_plain", "Shop ceiling (sheet metal, plain)", "str_interior_shop_ceiling_plain")
world_aligned("home_floor", "Home floor (wide planks)", "str_interior_home_floor", FLOOR)
world_aligned("home_wall", "Home wall (painted)", "str_interior_home_wall")
world_aligned("home_ceiling", "Home ceiling (dark boards)", "str_interior_home_ceiling")

-- Roll-down garage door: a slab 1/4 node thick, centred, full width and height. Three nodes stacked:
-- top (roll housing), mid (repeat as needed), bottom (end bar).
-- extra.use = a str_utils.constants.interact kind makes right-click call that kind's listeners
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
		def.on_rightclick = str_interior.make_on_rightclick(extra.use)
	end
	register_node(name, def)
end
str_interior.register_box = register_box

register_box("garage_door_top", "Garage door (top, housing)", "str_interior_garage_door_top", {
	{-16/32, -16/32, -4/32, 16/32, 10/32, 4/32},
	{-16/32, 10/32, -8/32, 16/32, 16/32, 8/32},
})
register_box("garage_door_mid", "Garage door (middle)", "str_interior_garage_door_mid", {
	{-16/32, -16/32, -4/32, 16/32, 16/32, 4/32},
})
register_box("garage_door_bottom", "Garage door (bottom, bar)", "str_interior_garage_door_bottom", {
	{-16/32, -13/32, -4/32, 16/32, 16/32, 4/32},
	{-16/32, -16/32, -6/32, 16/32, -13/32, 6/32},
})

-- Window: the same thin slab, a white frame around a bright pane. Opaque to the eye but daylight
-- passes through it (nodebox + paramtype light), no light of its own. 4 turns around Y only like
-- the digger display
register_box("window", "Window", "str_interior_window", {
	{-16/32, -16/32, -4/32, 16/32, 16/32, 4/32},
}, {paramtype2 = "4dir"})
