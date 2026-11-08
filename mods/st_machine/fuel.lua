local BAR = "st_machine:fuel"

st_hud.register_bar(BAR, {
	color = "#2ecc40", width = 240, height = 14, offset = {x = 130, y = -70},
	mode = "vehicle",
})

return st_machine.gauge.new({
	meta_key = "st_machine:fuel",
	max_stat = "max_fuel",
	on_change = function(player, level, max)
		st_hud.set_bar(player, BAR, level, max)
	end,
})
