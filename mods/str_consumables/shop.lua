local resources = str_player_resources
local SELL_LIST, SELL_SLOTS = "sell", 4

local function round2(x)
	return math.floor(x * 100 + 0.5) / 100
end

local sell_listeners = {}

function str_consumables.register_on_sell_change(fn)
	sell_listeners[#sell_listeners + 1] = fn
end

-- Items the player may buy: their blueprint is owned (the stock tier has none)
function str_consumables.available(player)
	local list = {}
	for _, name in ipairs(str_consumables.order) do
		local def = str_consumables.items[name]
		if not def.recipe or str_recipes.has(player, def.recipe) then
			list[#list + 1] = def
		end
	end
	return list
end

local KIND_NAMES = {fuel = "fuel canisters", repair = "repair kits"}

-- How many of a kind the player holds, hotbar and sell area together
local function held(player, kind)
	local count = 0
	local lists = {
		player:get_inventory():get_list("main") or {},
		core.get_inventory({type = "detached", name = str_consumables.sell_inventory_name(player)}):get_list(SELL_LIST) or {},
	}
	for _, list in ipairs(lists) do
		for _, stack in ipairs(list) do
			local def = str_consumables.items[stack:get_name()]
			if def and def.kind == kind then
				count = count + stack:get_count()
			end
		end
	end
	return count
end

-- Returns how many were bought and a message; stops at the per-kind limit
function str_consumables.buy(player, name, count)
	local def = str_consumables.items[name]
	if not def then
		return 0, ""
	end
	local room = str_consumables.MAX_PER_KIND - held(player, def.kind)
	if room <= 0 then
		return 0, ("You can carry at most %d %s."):format(str_consumables.MAX_PER_KIND, KIND_NAMES[def.kind])
	end
	local affordable = math.floor(resources.get_credits(player) / def.price + 1e-9)
	local wanted = math.min(count, room, affordable)
	if wanted <= 0 then
		return 0, "Not enough credits."
	end
	local left = player:get_inventory():add_item("main", ItemStack(name .. " " .. wanted))
	local bought = wanted - left:get_count()
	if bought <= 0 then
		return 0, "Your inventory is full."
	end
	resources.spend_credits(player, round2(bought * def.price))
	return bought, ("Bought %d x %s."):format(bought, def.description)
end

function str_consumables.sell_inventory_name(player)
	return "str_consumables:sell_" .. player:get_player_name()
end

local function sell_inv(player)
	return core.get_inventory({type = "detached", name = str_consumables.sell_inventory_name(player)})
end

function str_consumables.sell_value(player)
	local value = 0
	for _, stack in ipairs(sell_inv(player):get_list(SELL_LIST)) do
		local def = str_consumables.items[stack:get_name()]
		if def then
			value = value + stack:get_count() * def.price * str_consumables.sell_fraction
		end
	end
	return round2(value)
end

function str_consumables.sell_count(player)
	local count = 0
	for _, stack in ipairs(sell_inv(player):get_list(SELL_LIST)) do
		count = count + stack:get_count()
	end
	return count
end

-- Returns the credits paid
function str_consumables.sell(player)
	local value = str_consumables.sell_value(player)
	local inv = sell_inv(player)
	inv:set_list(SELL_LIST, {})
	inv:set_size(SELL_LIST, SELL_SLOTS)
	if value > 0 then
		resources.add_credits(player, value)
	end
	return value
end

-- Puts whatever is in the sell area back in the player's inventory; leftovers stay in the area
function str_consumables.return_items(player)
	local inv, main = sell_inv(player), player:get_inventory()
	for i, stack in ipairs(inv:get_list(SELL_LIST)) do
		if not stack:is_empty() then
			inv:set_stack(SELL_LIST, i, main:add_item("main", stack))
		end
	end
end

local function changed(player)
	for _, fn in ipairs(sell_listeners) do
		fn(player)
	end
end

local function sellable(stack)
	return str_consumables.items[stack:get_name()] and stack:get_count() or 0
end

core.register_on_joinplayer(function(player)
	local inv = core.create_detached_inventory(str_consumables.sell_inventory_name(player), {
		allow_put = function(_, _, _, stack) return sellable(stack) end,
		allow_move = function(inv, from_list, from_index, _, _, count)
			return sellable(inv:get_stack(from_list, from_index)) > 0 and count or 0
		end,
		on_put = function(_, _, _, _, who) changed(who) end,
		on_take = function(_, _, _, _, who) changed(who) end,
		on_move = function(_, _, _, _, _, _, who) changed(who) end,
	}, player:get_player_name())
	inv:set_size(SELL_LIST, SELL_SLOTS)
end)

core.register_on_leaveplayer(function(player)
	str_consumables.return_items(player)
	core.remove_detached_inventory(str_consumables.sell_inventory_name(player))
end)
