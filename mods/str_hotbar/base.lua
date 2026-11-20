-- The engine wields only from "main", so it holds the current mode's hotbar and the other one waits in PARKED.
-- Player meta MAIN_KEY says which kind "main" holds; empty means the machine hotbar (all saves before the hand hotbar)
local SLOTS = 8
local PARKED = "str_hotbar_parked"
local MAIN_KEY = "str_hotbar:main"
local FOOT_ITEM = str_groups.FOOT_ITEM

str_hotbar.SLOTS = SLOTS
str_hotbar.PARKED = PARKED

-- "foot" for hand hotbar items, "vehicle" for everything else, nil for an empty stack
function str_hotbar.kind(item)
	local name = type(item) == "string" and item or item:get_name()
	if name == "" then
		return nil
	end
	return core.get_item_group(name, FOOT_ITEM) > 0 and "foot" or "vehicle"
end

local function main_kind(player)
	return player:get_meta():get_string(MAIN_KEY) == "foot" and "foot" or "vehicle"
end

local function other(kind)
	return kind == "foot" and "vehicle" or "foot"
end

-- The inventory list holding the hotbar of kind ("vehicle" or "foot")
function str_hotbar.list(player, kind)
	return main_kind(player) == kind and "main" or PARKED
end

-- The hotbar kind a list holds, nil if it is not a hotbar list
function str_hotbar.list_kind(player, listname)
	if listname == "main" then
		return main_kind(player)
	elseif listname == PARKED then
		return other(main_kind(player))
	end
end

function str_hotbar.is_list(listname)
	return listname == "main" or listname == PARKED
end

-- Adds the stack to the hotbar of its kind; returns the leftover
function str_hotbar.give(player, stack)
	stack = ItemStack(stack)
	local kind = str_hotbar.kind(stack)
	if not kind then
		return stack
	end
	return player:get_inventory():add_item(str_hotbar.list(player, kind), stack)
end

function str_hotbar.room_for(player, stack)
	stack = ItemStack(stack)
	local kind = str_hotbar.kind(stack)
	return kind ~= nil and player:get_inventory():room_for_item(str_hotbar.list(player, kind), stack)
end

-- Moves stacks that sit in the other kind's hotbar (e.g. from a debug give) over where there is room
local function sort_out(player)
	local inv = player:get_inventory()
	for _, listname in ipairs({"main", PARKED}) do
		local kind = str_hotbar.list_kind(player, listname)
		for i, stack in ipairs(inv:get_list(listname)) do
			local stack_kind = str_hotbar.kind(stack)
			if stack_kind and stack_kind ~= kind then
				inv:set_stack(listname, i, inv:add_item(str_hotbar.list(player, stack_kind), stack))
			end
		end
	end
end

local function swap_to(player, kind)
	local inv = player:get_inventory()
	inv:set_size("main", SLOTS)
	inv:set_size(PARKED, SLOTS)
	if main_kind(player) ~= kind then
		local main, parked = inv:get_list("main"), inv:get_list(PARKED)
		inv:set_list("main", parked)
		inv:set_list(PARKED, main)
		player:get_meta():set_string(MAIN_KEY, kind == "foot" and "foot" or "")
	end
	sort_out(player)
end

str_mode.register_on_change(function(player, mode)
	swap_to(player, mode == "foot" and "foot" or "vehicle")
	player:hud_set_hotbar_itemcount(SLOTS)
end)

-- Saved with the machine hotbar in "main", as older versions expect
core.register_on_leaveplayer(function(player)
	swap_to(player, "vehicle")
end)

-- An item may only enter the hotbar of its own kind (swaps are checked both ways by the engine)
core.register_allow_player_inventory_action(function(player, action, inv, info)
	local stack, to_list
	if action == "move" then
		stack, to_list = inv:get_stack(info.from_list, info.from_index), info.to_list
	elseif action == "put" then
		stack, to_list = info.stack, info.listname
	else
		return
	end
	local want, kind = str_hotbar.list_kind(player, to_list), str_hotbar.kind(stack)
	if want and kind and kind ~= want then
		return 0
	end
end)
