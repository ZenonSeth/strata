-- Most of one explosive a player may hold in the hotbar
local MAX_CARRIED = 50

local function disc(radius)
	return function()
		local cells = {}
		for dx = -radius, radius do
			for dy = -radius, radius do
				if dx * dx + dy * dy <= radius * radius then
					cells[#cells + 1] = {dx, dy}
				end
			end
		end
		return cells
	end
end

local function row(reach)
	return function()
		local cells = {}
		for dx = -reach, reach do
			if dx ~= 0 then
				cells[#cells + 1] = {dx, 0}
			end
		end
		return cells
	end
end

-- cells() gives {dx, dy} offsets from the machine cell, in the slice plane
str_explosives.items = {
	{name = "str_explosives:weak", description = "Weak explosive", image = "str_explosives_weak.png",
		info = "Destroys nodes up to tier 4 in a circle around the machine; ground content is destroyed",
		tier = 4, cells = disc(2)},
	{name = "str_explosives:line", description = "Line charge", image = "str_explosives_line.png",
		info = "Horizontal: destroys nodes up to tier 6 in a row, 3 to each side of the machine; ground content is destroyed",
		tier = 6, cells = row(3)},
	{name = "str_explosives:tnt", description = "TNT", image = "str_explosives_tnt.png",
		info = "Destroys nodes up to tier 8 in a large circle around the machine; ground content is destroyed",
		tier = 8, cells = disc(4)},
	{name = "str_explosives:c4", description = "C4", image = "str_explosives_c4.png",
		info = "Destroys nodes up to tier 9 in a large circle around the machine; ground content is destroyed",
		tier = 9, cells = disc(5)},
	{name = "str_explosives:c4_shaped", description = "Shaped C4", image = "str_explosives_c4_shaped.png",
		info = "Horizontal: destroys nodes up to tier 9 in a row, 4 to each side of the machine; ground content is destroyed",
		tier = 9, cells = row(4)},
}

str_audio.sfx.register("blast", {sound = "str_explosives_blast", max_hear_distance = 48})

local function detonate(player, def)
	local pos = str_machine.get_pos(player)
	if not pos then
		return false
	end
	local center = vector.round(pos)
	str_audio.sfx.play("blast", {pos = center})
	for _, cell in ipairs(def.cells()) do
		str_machine.destroy_node(player, vector.offset(center, cell[1], cell[2], 0), def.tier)
	end
	return true
end

local by_name = {}
for _, def in ipairs(str_explosives.items) do
	by_name[def.name] = def
	core.register_craftitem(def.name, {
		description = def.description .. "\n" .. def.info,
		short_description = def.description,
		inventory_image = def.image,
		stack_max = MAX_CARRIED,
		on_use = function(itemstack, user)
			if not user or str_mode.get(user) ~= "vehicle" or str_machine.is_dead(user)
					or str_machine.blocked_on_surface(user) then
				return
			end
			if detonate(user, def) then
				itemstack:take_item()
				return itemstack
			end
		end,
		on_drop = function(itemstack) return itemstack end,
	})
end

local function held(inv, listname, name)
	local total = 0
	for _, stack in ipairs(inv:get_list(listname) or {}) do
		if stack:get_name() == name then
			total = total + stack:get_count()
		end
	end
	return total
end

-- Moves within the hotbar change nothing; anything arriving from elsewhere must stay under the cap
core.register_allow_player_inventory_action(function(player, action, inv, info)
	local hotbar = str_hotbar.list(player, "vehicle")
	local stack, amount
	if action == "move" and info.to_list == hotbar and info.from_list ~= hotbar then
		stack, amount = inv:get_stack(info.from_list, info.from_index), info.count
	elseif action == "put" and info.listname == hotbar then
		stack, amount = info.stack, info.stack:get_count()
	end
	if stack and by_name[stack:get_name()] and held(inv, hotbar, stack:get_name()) + amount > MAX_CARRIED then
		return 0
	end
end)
