local BAR = "str_machine:hull"

str_hud.register_bar(BAR, {
	color = str_utils.constants.colors.hull, width = 240, height = 20, size = 1.1, offset = {x = -130, y = -106},
	mode = "vehicle",
})

local hull = str_machine.gauge.new({
	max_stat = "max_hull",
	-- Each hull part keeps its own hit points
	read = function(player)
		return str_machine.stats.get_part_value(player, "hull")
	end,
	write = function(player, amount)
		str_machine.stats.set_part_value(player, "hull", amount)
	end,
	on_change = function(player, level, max)
		str_hud.set_bar(player, BAR, level, max)
	end,
})

-- Returns how much damage was applied; the machine is destroyed at 0
function hull.damage(player, amount)
	local applied = hull.remove(player, amount)
	if hull.is_empty(player) then
		str_machine.destroy(player)
	end
	return applied
end

str_machine.hull = hull
