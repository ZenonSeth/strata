local SLOTS = 8

local stats = str_machine.stats
local hulls = str_machine_data.get_upgrade("hull")

local function hull_index(player)
	local name = stats.get_level(player, "hull").name
	for i, level in ipairs(hulls.levels) do
		if level.name == name then
			return i
		end
	end
end

local constants = str_utils.constants
local PAD = vector.new(constants.shop_x, constants.surface_y + 1, constants.slice_z)

local function open_spot(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return node.name ~= "ignore" and def and not def.walkable and def.liquidtype == "none"
end

local function random_spot()
	local radius = str_consumables.teleport_radius
	for _ = 1, 200 do
		local pos = vector.offset(PAD, math.random(-radius, radius), math.random(-radius, radius), 0)
		if vector.distance(pos, PAD) <= radius and open_spot(pos) then
			return pos
		end
	end
end

local use = {
	teleport = function(player, def)
		local target = PAD
		if not def.stable then
			local radius = str_consumables.teleport_radius
			core.load_area(vector.offset(PAD, -radius, -radius, 0), vector.offset(PAD, radius, radius, 0))
			target = random_spot()
			if not target then
				str_utils.show_popup(player:get_player_name(), "The teleporter fizzles. Try again.", 2, true)
				return false
			end
		else
			core.load_area(PAD)
		end
		str_machine.teleport(player, target)
		return true
	end,
	fuel = function(player, def)
		if str_machine.fuel.add(player, def.amount) > 0 then
			str_audio.sfx.play("refuel", {player = player})
			return true
		end
		return false
	end,
	repair = function(player, def)
		if hull_index(player) > def.level + 1 then
			str_utils.show_popup(player:get_player_name(), "This kit is too weak for your hull.", 2, true)
			return false
		end
		return str_machine.hull.add(player, def.amount) > 0
	end,
}

for name, def in pairs(str_consumables.items) do
	core.register_craftitem(name, {
		description = def.tooltip and (def.description .. "\n" .. def.tooltip) or def.description,
		short_description = def.description,
		inventory_image = def.image,
		stack_max = str_consumables.MAX_PER_KIND,
		on_use = function(itemstack, user)
			if not user or str_mode.get(user) ~= "vehicle" or str_machine.is_dead(user) then
				return
			end
			if use[def.kind](user, def) then
				itemstack:take_item()
				return itemstack
			end
		end,
		on_drop = function(itemstack) return itemstack end,
	})
end

core.register_on_joinplayer(function(player)
	player:get_inventory():set_size("main", SLOTS)
	player:hud_set_hotbar_itemcount(SLOTS)
end)
