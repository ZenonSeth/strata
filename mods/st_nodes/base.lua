local DIRT_LEVELS = 10
local DIRT_COLOR_TOP = {0xa0, 0x76, 0x4a}
local DIRT_COLOR_DEEP = {0x3a, 0x2a, 0x20}
local DIRT_HARDNESS_TOP = 0.3
local DIRT_HARDNESS_DEEP = 60

local function fill(color)
	return "[fill:16x16:" .. color
end

local function lerp_color(a, b, t)
	local out = "#"
	for i = 1, 3 do
		out = out .. string.format("%02x", math.floor(a[i] + (b[i] - a[i]) * t + 0.5))
	end
	return out
end

local shapes = st_nodes.shapes

-- base name -> {[mask] = {node names}}, mask 0 being the base itself
local shaped = {}

-- Solid hand-diggable node plus its shaped variants (masks 1..15 with shapes.VARIANTS rough
-- variants each, see shapes.lua); def.groups, if given, overrides the common groups
function st_nodes.register_shaped_node(name, def)
	def = table.copy(def)
	def.groups = st_utils.get_common_groups(def.groups)
	def.groups.not_in_creative_inventory = 1
	local names = {[0] = {name}}
	for mask = 1, shapes.COUNT - 1 do
		names[mask] = {}
		for n = 1, shapes.VARIANTS do
			local variant = table.copy(def)
			variant.drawtype = "nodebox"
			variant.paramtype = "light"
			variant.node_box = {type = "fixed", fixed = shapes.boxes(mask, n)}
			variant.collision_box = {type = "fixed", fixed = shapes.FULL}
			variant.selection_box = {type = "fixed", fixed = shapes.FULL}
			variant.groups = table.copy(def.groups)
			variant.st_base = name
			variant.drop = name
			names[mask][n] = shapes.variant_name(name, mask, n)
			core.register_node(names[mask][n], variant)
		end
	end
	shaped[name] = names
	core.register_node(name, def)
end

local NEIGHBOURS = {
	{bit = shapes.TOP, dir = vector.new(0, 1, 0)},
	{bit = shapes.BOTTOM, dir = vector.new(0, -1, 0)},
	{bit = shapes.LEFT, dir = vector.new(-1, 0, 0)},
	{bit = shapes.RIGHT, dir = vector.new(1, 0, 0)},
}

-- Air and liquids are missing; unloaded and unknown nodes count as present
local function is_missing(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return node.name ~= "ignore" and def ~= nil and def.walkable == false
end

local function refresh_node(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	local names = shaped[def and def.st_base or node.name]
	if not names then
		return
	end
	local mask = 0
	for _, n in ipairs(NEIGHBOURS) do
		if is_missing(vector.add(pos, n.dir)) then
			mask = mask + n.bit
		end
	end
	local options = names[mask]
	local target = options[shapes.pick(pos.x, pos.y, pos.z, #options)]
	if target ~= node.name then
		core.set_node(pos, {name = target, param1 = node.param1, param2 = node.param2})
	end
end

-- Call after a node at pos was removed, placed or replaced; liquid flow needs no call
function st_nodes.refresh_shapes(pos)
	refresh_node(pos)
	for _, n in ipairs(NEIGHBOURS) do
		refresh_node(vector.add(pos, n.dir))
	end
end

core.register_on_dignode(function(pos)
	st_nodes.refresh_shapes(pos)
end)

core.register_on_placenode(function(pos)
	st_nodes.refresh_shapes(pos)
end)

for _, def in ipairs({
	{name = "soft", color = "#8b5a2b", hardness = 0.3},
	{name = "medium", color = "#808080", hardness = 1},
	{name = "hard", color = "#404050", hardness = 3},
}) do
	core.register_node("st_nodes:" .. def.name, {
		description = "Dig test node (" .. def.name .. ")",
		tiles = {fill(def.color)},
		groups = st_utils.get_common_groups(),
		st_hardness = def.hardness,
	})
end

for level = 1, DIRT_LEVELS do
	local t = (level - 1) / (DIRT_LEVELS - 1)
	local hardness = DIRT_HARDNESS_TOP * (DIRT_HARDNESS_DEEP / DIRT_HARDNESS_TOP) ^ t
	st_nodes.register_shaped_node("st_nodes:dirt_" .. level, {
		description = "Dirt (level " .. level .. ")",
		tiles = {fill(lerp_color(DIRT_COLOR_TOP, DIRT_COLOR_DEEP, t))},
		st_hardness = math.floor(hardness * 100 + 0.5) / 100,
	})
end

-- Strata, materials and gems come from the data files

local data = st_nodes.data
local strata, materials, gems = data.strata, data.materials, data.gems

local MAX_OVERLAP = data.max_overlap
local WORLD_SCALE = 8
-- Rock with param2 128..255 (the backing wall) is tinted this colour; 0..127 is untinted
local BACK_SHADE = "#d0d0d0"
local ROCK_PALETTE = "[fill:2x1:#ffffff^[fill:1x1:1,0:" .. BACK_SHADE
local ORE_RICHNESS = {
	{name = "poor", yield = 1, hardness = 1, mark = 4},
	{name = "regular", yield = 2, hardness = 1.15, mark = 8},
	{name = "rich", yield = 3, hardness = 1.3, mark = 12},
}

for i, s in ipairs(strata) do
	local nxt = strata[i + 1]
	assert(not s.to or s.to > s.from, "strata: " .. s.name .. " ends before it starts")
	if nxt then
		assert(nxt.from > s.from and nxt.tier >= s.tier, "strata: bad order at " .. nxt.name)
		assert(s.to and s.to - nxt.from <= MAX_OVERLAP, "strata: overlap too big at " .. nxt.name)
		if strata[i + 2] then
			assert(s.to <= strata[i + 2].from, "strata: " .. s.name .. " overlaps a non-neighbour")
		end
	end
end

local function tier_hardness(tier)
	local t = (tier - 1) / 9
	local h = DIRT_HARDNESS_TOP * (DIRT_HARDNESS_DEEP / DIRT_HARDNESS_TOP) ^ t
	return math.floor(h * 100 + 0.5) / 100
end

local function has_texture(file, modpath)
	local f = io.open((modpath or st_nodes.modpath) .. "/textures/" .. file, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

local function hsv_color(h, s, v)
	local out = "#"
	for _, n in ipairs({5, 3, 1}) do
		local k = (n + h * 6) % 6
		local c = v - v * s * math.max(0, math.min(k, 4 - k, 1))
		out = out .. string.format("%02x", math.floor(c * 255 + 0.5))
	end
	return out
end

local function name_color(name)
	local h = 0
	for i = 1, #name do
		h = (h * 31 + name:byte(i)) % 360
	end
	return hsv_color(h / 360, 0.6, 0.85)
end

local function world_tile(file)
	return {name = file, align_style = "world", scale = WORLD_SCALE}
end

-- Rock: world-aligned texture if the file exists, else a flat colour that darkens with depth
local function rock_tile(i)
	local file = "st_nodes_rock_" .. strata[i].name .. ".png"
	if has_texture(file) then
		return world_tile(file)
	end
	return fill(lerp_color({0xb0, 0x95, 0x6a}, {0x30, 0x28, 0x2c}, (i - 1) / (#strata - 1)))
end

for i, s in ipairs(strata) do
	st_nodes.register_shaped_node("st_nodes:" .. s.name, {
		description = s.description,
		tiles = {rock_tile(i)},
		paramtype2 = "color",
		palette = ROCK_PALETTE,
		st_tier = s.tier,
		st_hardness = tier_hardness(s.tier),
	})
end

-- Surface row: topsoil with a top and side overlay; snow and sand reuse the grass art, recoloured
local CLEAR_TILE = fill("#00000000")
local SIDE_STRIP_W, SIDE_STRIP_H = 256, 32

-- The side file is one strip, one node row tall; stack it to span the world-aligned tile
local function stack_rows(file)
	local parts = {}
	for row = 0, WORLD_SCALE - 1 do
		parts[#parts + 1] = "0," .. row * SIDE_STRIP_H .. "=" .. file
	end
	return "[combine:" .. SIDE_STRIP_W .. "x" .. SIDE_STRIP_H * WORLD_SCALE .. ":" ..
		table.concat(parts, ":")
end
local SURFACE_TYPES = {
	{name = "grass", description = "Grass", tint = "#ffffff:0"},
	{name = "snow", description = "Snow", tint = "#ffffff:200"},
	{name = "sand", description = "Sand", tint = "#e0cc8c:200"},
}

for _, t in ipairs(SURFACE_TYPES) do
	local top, side = "st_nodes_surface_" .. t.name .. "_top.png", "st_nodes_surface_" .. t.name .. "_side.png"
	local suffix = ""
	if not (has_texture(top) and has_texture(side)) then
		suffix = "^[colorize:" .. t.tint
		top = "st_nodes_surface_grass_top.png"
		side = "st_nodes_surface_grass_side.png"
	end
	top = top .. suffix
	side = stack_rows(side) .. suffix
	-- Backdrop cover (behind the slice): the top art world-aligned on every side
	core.register_node("st_nodes:surface_" .. t.name .. "_back", {
		description = t.description .. " (backdrop)",
		tiles = {world_tile(top)},
		groups = st_utils.get_common_groups({not_in_creative_inventory = 1}),
		st_tier = strata[1].tier,
		st_hardness = tier_hardness(strata[1].tier),
	})
	core.register_node("st_nodes:surface_" .. t.name, {
		description = t.description,
		tiles = {rock_tile(1)},
		-- Side overlay disabled: it flickers; `side` is built but unused
		overlay_tiles = {top, CLEAR_TILE, CLEAR_TILE, CLEAR_TILE, CLEAR_TILE, CLEAR_TILE},
		groups = st_utils.get_common_groups({not_in_creative_inventory = 1}),
		st_tier = strata[1].tier,
		st_hardness = tier_hardness(strata[1].tier),
	})
end

-- Ore and gems: the host rock's tile with an overlay texture, or marks as a placeholder
local function placeholder_overlay(color, mark)
	local size = 16 * WORLD_SCALE
	local offset = (16 - mark) / 2
	local parts = {"[fill:" .. size .. "x" .. size .. ":#00000000"}
	for cy = 0, WORLD_SCALE - 1 do
		for cx = 0, WORLD_SCALE - 1 do
			parts[#parts + 1] = "[fill:" .. mark .. "x" .. mark .. ":" ..
				(cx * 16 + offset) .. "," .. (cy * 16 + offset) .. ":" .. color
		end
	end
	return table.concat(parts, "^")
end

-- A gem file is one node cell; repeat it over the whole world-aligned tile
local function cell_tile(file)
	local cell = math.floor(256 / WORLD_SCALE)
	local parts = {}
	for cy = 0, WORLD_SCALE - 1 do
		for cx = 0, WORLD_SCALE - 1 do
			parts[#parts + 1] = cx * cell .. "," .. cy * cell .. "=" .. file
		end
	end
	return world_tile("[combine:256x256:" .. table.concat(parts, ":"))
end

local function register_embedded(node_name, description, file, color, mark, host, def, cell)
	def.tiles = {rock_tile(host)}
	local overlay
	if has_texture(file, cell and st_materials.modpath) then
		overlay = cell and cell_tile(file) or world_tile(file)
	else
		overlay = placeholder_overlay(color, mark)
	end
	def.overlay_tiles = {overlay}
	def.description = description
	def.groups = st_utils.get_common_groups({not_in_creative_inventory = 1})
	core.register_node(node_name, def)
end

for host, s in ipairs(strata) do
	for _, m in ipairs(materials) do
		if not m.liquid then
			for _, r in ipairs(ORE_RICHNESS) do
				register_embedded(data.ore_node(m.name, r.name, s.name),
					st_materials.get(m.name).description .. " (" .. r.name .. ", " .. s.name .. ")",
					"st_nodes_ore_" .. m.name .. "_" .. r.name .. ".png", name_color(m.name), r.mark, host, {
						st_material = m.name,
						st_tier = m.tier,
						st_yield = r.yield,
						st_hardness = math.floor(tier_hardness(m.tier) * r.hardness * 100 + 0.5) / 100,
					})
			end
		end
	end

	for _, g in ipairs(gems) do
		register_embedded(data.gem_node(g.name, s.name), st_materials.get(g.name).description .. " (" .. s.name .. ")",
			"st_materials_" .. g.name .. ".png", name_color(g.name), 6, host, {
				st_material = g.name,
				st_tier = g.tier,
				st_yield = 1,
				st_hardness = tier_hardness(g.tier),
			}, true)
	end
end

-- Rock formations: obstacle mesh nodes, one per mesh variant, solid like any rock
local FORMATION_SCALE = 1.1
local FULL_BOX = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}}
for _, f in ipairs(data.formations) do
	local file = "st_nodes_formation_" .. f.name .. ".png"
	for n = 1, data.formation_variants do
		core.register_node(data.formation_node(f.name, n), {
			description = f.description,
			drawtype = "mesh",
			mesh = "st_nodes_rock_" .. n .. ".obj",
			visual_scale = FORMATION_SCALE,
			tiles = {has_texture(file) and file or fill("#808080")},
			paramtype = "light",
			collision_box = FULL_BOX,
			selection_box = FULL_BOX,
			groups = st_utils.get_common_groups({not_in_creative_inventory = 1}),
			drop = "",
			st_tier = f.tier,
			st_hardness = tier_hardness(f.tier),
		})
	end
end

-- Liquids: only source nodes are collected, they never renew
local LIQUIDS = {
	oil = {viscosity = 3, color = "#1c1a14", light = 0},
	lava = {viscosity = 5, color = "#e8501a", light = 13, damage = 4},
}

for _, m in ipairs(materials) do
	local l = LIQUIDS[m.name]
	if m.liquid and l then
		local file = "st_nodes_liquid_" .. m.name .. ".png"
		local tex = has_texture(file) and file or fill(l.color)
		local common = {
			tiles = {tex},
			special_tiles = {{name = tex, backface_culling = false}, {name = tex, backface_culling = false}},
			use_texture_alpha = "opaque",
			paramtype = "light",
			light_source = l.light,
			walkable = false,
			pointable = true,
			diggable = false,
			buildable_to = true,
			is_ground_content = false,
			drop = "",
			liquid_viscosity = l.viscosity,
			liquid_renewable = false,
			damage_per_second = l.damage,
			groups = {liquid = 1, not_in_creative_inventory = 1},
			st_material = m.name,
		}
		local function make(extra)
			local def = table.copy(common)
			for k, v in pairs(extra) do
				def[k] = v
			end
			return def
		end
		local source = "st_nodes:" .. m.name .. "_source"
		local flowing = "st_nodes:" .. m.name .. "_flowing"
		core.register_node(source, make({
			description = st_materials.get(m.name).description,
			drawtype = "liquid",
			liquidtype = "source",
			liquid_alternative_flowing = flowing,
			liquid_alternative_source = source,
			st_yield = 1,
		}))
		core.register_node(flowing, make({
			description = "Flowing " .. st_materials.get(m.name).description:lower(),
			drawtype = "flowingliquid",
			paramtype2 = "flowingliquid",
			liquidtype = "flowing",
			liquid_alternative_flowing = flowing,
			liquid_alternative_source = source,
		}))
	end
end

-- Invisible wall for the ends of the map; solid to the machine and the player
core.register_node("st_nodes:barrier", {
	description = "Barrier",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = true,
	pointable = false,
	diggable = false,
	buildable_to = false,
	groups = {not_in_creative_inventory = 1},
})

-- Invisible, non-walkable layer in front of the slice so liquids cannot flow forward
core.register_node("st_nodes:liquid_stop", {
	description = "Liquid Stop",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	groups = {not_in_creative_inventory = 1},
})
