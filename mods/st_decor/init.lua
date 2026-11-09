st_decor = {}

-- Tufts are plantlike nodes: a texture (tools/gen_decor.py) with transparent pixels, blades along the bottom
local BIOMES = {"grass", "snow", "sand"}
local TUFT_VARIANTS = 3

for _, biome in ipairs(BIOMES) do
	for variant = 1, TUFT_VARIANTS do
		core.register_node("st_decor:tuft_" .. biome .. "_" .. variant, {
			description = "Grass tuft (" .. biome .. ")",
			drawtype = "plantlike",
			paramtype = "light",
			paramtype2 = "meshoptions",
			sunlight_propagates = true,
			tiles = {"st_decor_tuft_" .. biome .. "_" .. variant .. ".png"},
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

-- Bushes and trees are nodeboxes from tools/gen_decor.py (art/decor_*.nbx); trees are a base node
-- with a top node above it. Facedir rotates the off-centre shapes
for _, def in ipairs(dofile(core.get_modpath("st_decor") .. "/shapes.lua")) do
	local t = def.texture
	core.register_node("st_decor:" .. def.name, {
		description = def.name:gsub("_", " "),
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		tiles = {t .. "_top.png", t .. "_bottom.png", t .. "_left.png", t .. "_right.png", t .. "_back.png", t .. "_front.png"},
		node_box = {type = "fixed", fixed = def.boxes},
		walkable = false,
		pointable = false,
		diggable = false,
		buildable_to = true,
		is_ground_content = false,
		groups = {not_in_creative_inventory = 1},
	})
end
