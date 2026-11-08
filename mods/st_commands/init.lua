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
