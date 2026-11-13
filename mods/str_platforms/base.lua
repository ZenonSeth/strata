local NODE = "str_platforms:platform"
local SLICE_Z = str_utils.constants.slice_z

-- Seconds to dig a platform; long so it is never dug by accident
local DIG_TIME = 30

local ground = {}
for _, stratum in ipairs(str_nodes.data.strata) do
	ground["str_nodes:" .. stratum.name] = true
end
for _, biome in ipairs(str_utils.constants.biomes) do
	ground["str_nodes:surface_" .. biome.name] = true
	ground["str_nodes:surface_" .. biome.name .. "_back"] = true
end

local TEXTURE = "str_platforms_grate.png"

core.register_node(NODE, {
	description = "Platform",
	drawtype = "nodebox",
	node_box = {type = "fixed", fixed = {-0.5, 0.4375, -0.5, 0.5, 0.5, 0.5}},
	paramtype = "light",
	sunlight_propagates = true,
	tiles = {TEXTURE},
	use_texture_alpha = "clip",
	groups = {not_in_creative_inventory = 1},
	is_ground_content = false,
	str_platform = true,
	str_hardness = DIG_TIME,
	-- Dug platforms go to a free hotbar slot, or are lost
	str_on_dug = function(player)
		local inv = player:get_inventory()
		local stack = ItemStack(NODE)
		for slot = 1, player:hud_get_hotbar_itemcount() do
			local current = inv:get_stack("main", slot)
			if current:item_fits(stack) then
				current:add_item(stack)
				inv:set_stack("main", slot, current)
				return
			end
		end
	end,
})

local function is_ground(pos)
	return ground[core.get_node(pos).name] == true
end

core.register_craftitem(NODE, {
	description = "Platform\nPlaced below the machine to stand on; dig it from above",
	short_description = "Platform",
	inventory_image = TEXTURE,
	on_use = function(itemstack, user)
		if not user or str_mode.get(user) ~= "vehicle" or str_machine.is_dead(user) then
			return
		end
		local at = str_machine.get_pos(user)
		if not at then
			return
		end
		local pos = vector.new(math.floor(at.x + 0.5), math.floor(at.y + 0.5) - 1, SLICE_Z)
		local current = core.get_node(pos).name
		local free = current == "air" or ground[current]
		if not (free and is_ground(vector.offset(pos, 0, 0, 1))) then
			str_utils.show_popup(user:get_player_name(), "A platform can't be placed here.", 2, true)
			return
		end
		core.set_node(pos, {name = NODE})
		itemstack:take_item()
		return itemstack
	end,
	on_drop = function(itemstack) return itemstack end,
})
