-- All chat commands live here; this mod depends on the others, never the reverse
local function register_mode_command(command, mode, description, message)
	core.register_chatcommand(command, {
		description = description,
		func = function(name)
			local player = core.get_player_by_name(name)
			if not player then
				return false, "No such player."
			end
			st_mode.set(player, mode)
			return true, message
		end,
	})
end

register_mode_command("foot", "foot", "Get out of the machine and walk", "On foot.")
register_mode_command("drive", "vehicle", "Get back into the machine", "Driving.")

core.register_chatcommand("guitest", {
	description = "Show a window with the common formspec elements on a grid",
	func = function(name)
		st_gui.show_test(name)
		return true, "GUI test."
	end,
})

dofile(st_commands.modpath .. "/give.lua")

core.register_chatcommand("transmit", {
	description = "Debug: receive a test transmission (\"reset\" clears them and hides the tab)",
	params = "[reset]",
	func = function(name, param)
		if param == "reset" then
			st_transmissions.reset(name)
			return true, "Transmissions cleared."
		end
		st_transmissions.add(name, "@#!? @#!? !!?#", "pattern: noise, repeating")
		return true, "Transmission received."
	end,
})
