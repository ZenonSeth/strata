local BAR = "st_machine:fuel"

st_hud.register_bar(BAR, {
	color = st_utils.constants.colors.fuel, width = 240, height = 20, size = 1.1, offset = {x = 130, y = -94},
	mode = "vehicle", decimal = true,
})

st_machine.fuel = st_machine.gauge.new({
	meta_key = "st_machine:fuel",
	max_stat = "max_fuel",
	on_change = function(player, level, max)
		st_hud.set_bar(player, BAR, level, max)
	end,
})
