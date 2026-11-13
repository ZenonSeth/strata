local SLOTS = 8

local stats = st_machine.stats
local hulls = st_machine_data.get_upgrade("hull")

local function hull_index(player)
	local name = stats.get_level(player, "hull").name
	for i, level in ipairs(hulls.levels) do
		if level.name == name then
			return i
		end
	end
end

local use = {
	fuel = function(player, def)
		return st_machine.fuel.add(player, def.amount) > 0
	end,
	repair = function(player, def)
		if hull_index(player) > def.level then
			st_utils.show_popup(player:get_player_name(), "This kit is too weak for your hull.", 2, true)
			return false
		end
		return st_machine.hull.add(player, def.amount) > 0
	end,
}

for name, def in pairs(st_consumables.items) do
	core.register_craftitem(name, {
		description = def.tooltip and (def.description .. "\n" .. def.tooltip) or def.description,
		short_description = def.description,
		inventory_image = def.image,
		stack_max = st_consumables.MAX_PER_KIND,
		on_use = function(itemstack, user)
			if not user or st_mode.get(user) ~= "vehicle" or st_machine.is_dead(user) then
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
