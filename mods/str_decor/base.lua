-- Tufts are plantlike nodes: a texture with transparent pixels, blades along the bottom
local BIOMES = {"grass", "snow", "sand"}
local TUFT_VARIANTS = 3

for _, biome in ipairs(BIOMES) do
	for variant = 1, TUFT_VARIANTS do
		core.register_node("str_decor:tuft_" .. biome .. "_" .. variant, {
			description = "Grass tuft (" .. biome .. ")",
			drawtype = "plantlike",
			paramtype = "light",
			paramtype2 = "meshoptions",
			sunlight_propagates = true,
			tiles = {"str_decor_tuft_" .. biome .. "_" .. variant .. ".png"},
			use_texture_alpha = "clip",
			walkable = false,
			pointable = false,
			diggable = false,
			buildable_to = true,
			is_ground_content = false,
			groups = {not_in_creative_inventory = 1},
		})
	end
end

-- Widest x/z extent of each tree kind's base node
local trunk = {}
for _, def in ipairs(str_decor.shapes) do
	local kind = def.name:match("^tree_(%a+)_base$")
	if kind then
		local w = 0
		for _, b in ipairs(def.boxes) do
			w = math.max(w, -b[1], b[4], -b[3], b[6])
		end
		trunk[kind] = w
	end
end

local INNER_CROWNS = 1
-- Engine trunk column half-width; the machine slides round the full trunk as a cylinder (str_trunk_radius)
local TRUNK_CORE = 1/32
-- Leafy crowns collide this much smaller on each x/z side than they look
local CROWN_INSET = 4/32

-- Materials (str_materials names) a felled tree of each kind puts in the hold
local FELL_YIELD = {
	oak = {oak_timber = 2},
	pine = {pine_timber = 2},
	cactus = {cactus_fiber = 2, cactus_resin = 1},
}

-- Bushes and trees are nodeboxes (art/decor_*.nbx); trees are a base node
-- with a top node above it. Facedir rotates the off-centre shapes
for _, def in ipairs(str_decor.shapes) do
	local t = def.texture
	local w = trunk[def.name:match("^tree_(%a+)_") or ""]
	local holed = (def.name:find("^tree_%a+_%d_top$") ~= nil and not def.name:find("cactus")) or def.name:find("^bush_") ~= nil
	local collision
	if w then
		-- A full-height trunk column in both nodes, so the machine cannot step up onto the trunk
		collision = {{-TRUNK_CORE, -0.5, -TRUNK_CORE, TRUNK_CORE, 0.5, TRUNK_CORE}}
		if not def.name:find("_base$") then
			for _, b in ipairs(def.boxes) do
				local inset = holed and CROWN_INSET or 0
				local in_trunk = math.max(-b[1], b[4], -b[3], b[6]) <= w
				if not in_trunk and b[4] - b[1] > 2 * inset and b[6] - b[3] > 2 * inset then
					collision[#collision + 1] = {b[1] + inset, b[2], b[3] + inset, b[4] - inset, b[5], b[6] - inset}
				end
			end
		end
	end
	local tiles = {t .. "_top.png", t .. "_bottom.png", t .. "_left.png", t .. "_right.png", t .. "_back.png", t .. "_front.png"}
	local boxes = def.boxes
	if holed then
		-- Leaf holes show the inside of the far faces
		for i, name in ipairs(tiles) do
			tiles[i] = {name = name, backface_culling = false}
		end
		-- Sink a box resting on another into it: with no culling the shared plane z-fights
		boxes = {}
		for i, a in ipairs(def.boxes) do
			local b = table.copy(a)
			for j, o in ipairs(def.boxes) do
				if j ~= i and a[2] == o[5] and a[1] < o[4] and o[1] < a[4] and a[3] < o[6] and o[3] < a[6] then
					b[2] = a[2] - 1/64
				end
			end
			boxes[i] = b
		end
		-- Nested copies of the crown, evenly spaced towards its centre, give the holes inner surfaces
		local big, vol = nil, 0
		for _, b in ipairs(boxes) do
			local v = (b[4] - b[1]) * (b[5] - b[2]) * (b[6] - b[3])
			if v > vol then
				big, vol = b, v
			end
		end
		for k = 1, INNER_CROWNS do
			local f = k / (INNER_CROWNS + 1) / 2
			local inner = {}
			for a = 1, 3 do
				local d = (big[a + 3] - big[a]) * f
				inner[a], inner[a + 3] = big[a] + d, big[a + 3] - d
			end
			boxes[#boxes + 1] = inner
		end
	end
	core.register_node("str_decor:" .. def.name, {
		description = def.name:gsub("_", " "),
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		tiles = tiles,
		use_texture_alpha = holed and "clip" or nil,
		node_box = {type = "fixed", fixed = boxes},
		collision_box = collision and {type = "fixed", fixed = collision},
		walkable = collision ~= nil,
		str_trunk_radius = w,
		str_tree = w and (def.name:find("_base$") and "base" or "top") or nil,
		str_stump = w and def.name:find("_base$") and "str_decor:stump_" .. def.name:match("^tree_(%a+)_") or nil,
		str_dug_sound = w and "wood" or nil,
		str_fell_yield = w and def.name:find("_base$") and FELL_YIELD[def.name:match("^tree_(%a+)_")] or nil,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		groups = {not_in_creative_inventory = 1},
	})
end

-- Stumps are the bottom of the base node's boxes, left where a tree was cut down
local STUMP_TOP = -8/32
local shape_boxes = {}
local tops = {}
for _, def in ipairs(str_decor.shapes) do
	shape_boxes[def.name] = def.boxes
	local kind = def.name:match("^tree_(%a+)_%d_top$")
	if kind then
		tops[kind] = tops[kind] or {}
		table.insert(tops[kind], "str_decor:" .. def.name)
	end
end

local stumps = {}
for kind in pairs(trunk) do
	local base = "tree_" .. kind .. "_base"
	local boxes = {}
	for _, b in ipairs(shape_boxes[base]) do
		if b[2] < STUMP_TOP then
			boxes[#boxes + 1] = {b[1], b[2], b[3], b[4], math.min(b[5], STUMP_TOP), b[6]}
		end
	end
	local t = "str_decor_" .. base
	local name = "str_decor:stump_" .. kind
	stumps[#stumps + 1] = name
	core.register_node(name, {
		description = kind .. " stump",
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		tiles = {t .. "_top.png", t .. "_bottom.png", t .. "_left.png", t .. "_right.png", t .. "_back.png", t .. "_front.png"},
		node_box = {type = "fixed", fixed = boxes},
		walkable = false,
		str_regrow = "str_decor:" .. base,
		str_regrow_tops = tops[kind],
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		groups = {not_in_creative_inventory = 1},
	})
end

-- Sawdust flakes per cubic node of tree volume
local FELL_DENSITY = 250
local FELL_MIN_PER_BOX = 3
local SAWDUST = {"#b89b6c", "#a8885a", "#957447", "#c2a77c", "#85663e"}

-- Facedir 0-3 turns the node's +z towards core.facedir_to_dir(param2)
local function rotate(x, z, param2)
	for _ = 1, param2 % 4 do
		x, z = z, -x
	end
	return x, z
end

local function fell_particles(pos, node)
	local boxes = shape_boxes[node.name:match("^str_decor:(.+)$") or ""]
	if not boxes then
		return
	end
	for _, b in ipairs(boxes) do
		local volume = (b[4] - b[1]) * (b[5] - b[2]) * (b[6] - b[3])
		for _ = 1, math.max(FELL_MIN_PER_BOX, math.floor(volume * FELL_DENSITY + 0.5)) do
			local x, z = rotate(b[1] + math.random() * (b[4] - b[1]), b[3] + math.random() * (b[6] - b[3]), node.param2)
			core.add_particle({
				pos = vector.offset(pos, x, b[2] + math.random() * (b[5] - b[2]), z),
				velocity = vector.new((math.random() - 0.5) * 1.6, math.random() * 0.8, (math.random() - 0.5) * 1.6),
				acceleration = vector.new(0, -1.5, 0),
				expirationtime = 0.8 + math.random() * 0.8,
				size = 1.5 + math.random() * 2,
				texture = {name = "str_machine_puff.png^[multiply:" .. SAWDUST[math.random(#SAWDUST)], blend = "alpha",
					alpha_tween = {1, 0}},
			})
		end
	end
end

-- Removes the tree whose base node is at pos, with its top, and leaves a stump; returns whether there was one
function str_decor.fell(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	if not def or def.str_tree ~= "base" then
		return false
	end
	local above = vector.offset(pos, 0, 1, 0)
	local top = core.get_node(above)
	local top_def = core.registered_nodes[top.name]
	if top_def and top_def.str_tree == "top" then
		core.remove_node(above)
		fell_particles(above, top)
	end
	core.set_node(pos, {name = def.str_stump, param2 = node.param2})
	fell_particles(pos, node)
	return true
end

-- Average seconds for a stump to grow back is about interval * chance
local REGROW_INTERVAL = 30
local REGROW_CHANCE = 20

core.register_abm({
	label = "Stumps grow back into trees",
	nodenames = stumps,
	interval = REGROW_INTERVAL,
	chance = REGROW_CHANCE,
	action = function(pos, node)
		local above = vector.offset(pos, 0, 1, 0)
		local name = core.get_node(above).name
		if name ~= "air" and not name:find("^str_decor:") then
			return
		end
		local def = core.registered_nodes[node.name]
		local top_names = def.str_regrow_tops
		core.set_node(pos, {name = def.str_regrow, param2 = node.param2})
		core.set_node(above, {name = top_names[math.random(#top_names)], param2 = node.param2})
	end,
})
