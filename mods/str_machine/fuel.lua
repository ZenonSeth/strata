local BAR = "str_machine:fuel"

str_hud.register_bar(BAR, {
	color = str_utils.constants.colors.fuel, width = 240, height = 20, size = 1.1, offset = {x = 130, y = -106},
	mode = "vehicle", decimal = true,
})

str_machine.fuel = str_machine.gauge.new({
	meta_key = "str_machine:fuel",
	max_stat = "max_fuel",
	on_change = function(player, level, max)
		str_hud.set_bar(player, BAR, level, max)
	end,
})
