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
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		groups = {not_in_creative_inventory = 1},
	})
end
