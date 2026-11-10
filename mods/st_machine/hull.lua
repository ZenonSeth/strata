local BAR = "st_machine:hull"

st_hud.register_bar(BAR, {
	color = "#d32f2f", width = 240, height = 14, offset = {x = -130, y = -70},
	mode = "vehicle",
})

local hull = st_machine.gauge.new({
	max_stat = "max_hull",
	-- Each hull part keeps its own hit points
	read = function(player)
		return st_machine.stats.get_part_value(player, "hull")
	end,
	write = function(player, amount)
		st_machine.stats.set_part_value(player, "hull", amount)
	end,
	on_change = function(player, level, max)
		st_hud.set_bar(player, BAR, level, max)
	end,
})

-- Returns how much damage was applied; the machine is destroyed at 0
function hull.damage(player, amount)
	local applied = hull.remove(player, amount)
	if hull.is_empty(player) then
		st_machine.destroy(player)
	end
	return applied
end

st_machine.hull = hull
