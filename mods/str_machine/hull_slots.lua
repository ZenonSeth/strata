local hull_slots = {}

local LIST = "str_machine_hull"
local GROUP = "str_hull_upgrade"

hull_slots.LIST = LIST

hull_slots.items = {
	{name = "str_machine:hull_liquid_collection", description = "Liquid collection",
		info = "Hull upgrade, allows collection of liquids",
		image = "str_machine_hull_liquid_collection.png"},
	{name = "str_machine:hull_lava_protection", description = "Lava protection",
		info = "Hull upgrade, protects from lava for a time",
		image = "str_machine_hull_lava_protection.png"},
}

for _, def in ipairs(hull_slots.items) do
	core.register_craftitem(def.name, {
		description = def.description .. "\n" .. def.info,
		short_description = def.description,
		inventory_image = def.image,
		stack_max = 1,
		groups = {[GROUP] = 1},
		on_drop = function(itemstack) return itemstack end,
	})
end

function hull_slots.is_upgrade(item_name)
	return core.get_item_group(item_name, GROUP) > 0
end

function hull_slots.has(player, item_name)
	return player:get_inventory():contains_item(LIST, item_name)
end

function hull_slots.count(player)
	local n = 0
	for _, stack in ipairs(player:get_inventory():get_list(LIST) or {}) do
		if not stack:is_empty() then
			n = n + 1
		end
	end
	return n
end

-- Packs fitted upgrades to the front so shrinking the list never drops one
local function resize(player)
	local inv = player:get_inventory()
	local packed = {}
	for _, stack in ipairs(inv:get_list(LIST) or {}) do
		if not stack:is_empty() then
			packed[#packed + 1] = stack
		end
	end
	local size = str_machine.stats.get(player).hull_slots or 0
	for i = #packed + 1, size do
		packed[i] = ""
	end
	inv:set_size(LIST, size)
	if size > 0 then
		inv:set_list(LIST, packed)
	end
end

-- Lost with the machine
function hull_slots.clear(player)
	player:get_inventory():set_list(LIST, {})
end

str_machine.stats.register_equip_check("hull", function(player, level)
	if hull_slots.count(player) > (level.stats.hull_slots or 0) then
		return false, "Remove hull upgrades first."
	end
	return true
end)

str_machine.stats.register_on_change(resize)
core.register_on_joinplayer(resize)

-- Slots take one upgrade of each kind; upgrades never go to the hotbar
core.register_allow_player_inventory_action(function(_, action, inv, info)
	local stack, to_list, from_list
	if action == "move" then
		stack, to_list, from_list = inv:get_stack(info.from_list, info.from_index), info.to_list, info.from_list
	elseif action == "put" then
		stack, to_list = info.stack, info.listname
	else
		return
	end
	local upgrade = hull_slots.is_upgrade(stack:get_name())
	if to_list == "main" and upgrade then
		return 0
	end
	if to_list == LIST and from_list ~= LIST then
		if not upgrade or inv:contains_item(LIST, stack:get_name()) then
			return 0
		end
	end
end)

str_machine.hull_slots = hull_slots
