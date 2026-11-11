core.register_mapgen_script(st_worldgen.modpath .. "/mapgen.lua")

-- Active pads of the surface buildings placed in mapgen.lua; the other menus come later
local menus = {shop = st_start.show_workshop_menu, refinery = st_refinery.show, contact = st_company.show}
for id, label in pairs({shop = "Mechanic shop", refinery = "Ore refinery", contact = "Company contact"}) do
	st_pads.register(id, {
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
