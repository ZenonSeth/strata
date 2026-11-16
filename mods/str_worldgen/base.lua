core.register_mapgen_script(str_worldgen.modpath .. "/mapgen.lua")

-- World reset count, folded into the underground seeds; the mapgen script reads it over IPC
local storage = core.get_mod_storage()
local CYCLE_KEY = "cycle"
str_worldgen.CYCLE_IPC = "str_worldgen:cycle"
core.ipc_set(str_worldgen.CYCLE_IPC, storage:get_int(CYCLE_KEY))

function str_worldgen.get_cycle()
	return storage:get_int(CYCLE_KEY)
end

-- Chunks generated from now on get fresh underground content
function str_worldgen.next_cycle()
	local cycle = storage:get_int(CYCLE_KEY) + 1
	storage:set_int(CYCLE_KEY, cycle)
	core.ipc_set(str_worldgen.CYCLE_IPC, cycle)
	return cycle
end

-- Active pads of the surface buildings placed in mapgen.lua; the other menus come later
local menus = {shop = str_start.show_workshop_menu, refinery = str_refinery.show, contact = str_company.show}
for id, label in pairs({shop = "Mechanic shop", refinery = "Ore refinery", contact = "Company shop"}) do
	str_pads.register(id, {
		label = label,
		on_use = function(player)
			if menus[id] then
				menus[id](player)
			else
				core.chat_send_player(player:get_player_name(), label .. " (not built yet)")
			end
		end,
	})
end
