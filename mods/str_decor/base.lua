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

-- Bushes and trees are nodeboxes (art/decor_*.nbx); trees are a base node
-- with a top node above it. Facedir rotates the off-centre shapes
for _, def in ipairs(str_decor.shapes) do
	local t = def.texture
	local w = trunk[def.name:match("^tree_(%a+)_") or ""]
	local collision
	if w then
		-- A full-height trunk column in both nodes, so the machine cannot step up onto the trunk
		collision = {{-w, -0.5, -w, w, 0.5, w}}
		if not def.name:find("_base$") then
			for _, b in ipairs(def.boxes) do
				collision[#collision + 1] = b
			end
		end
	end
	core.register_node("str_decor:" .. def.name, {
		description = def.name:gsub("_", " "),
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		tiles = {t .. "_top.png", t .. "_bottom.png", t .. "_left.png", t .. "_right.png", t .. "_back.png", t .. "_front.png"},
		node_box = {type = "fixed", fixed = def.boxes},
		collision_box = collision and {type = "fixed", fixed = collision},
		walkable = collision ~= nil,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		groups = {not_in_creative_inventory = 1},
	})
end
