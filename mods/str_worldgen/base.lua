core.register_mapgen_script(str_worldgen.modpath .. "/mapgen.lua")

-- World reset count per slice z, folded into the underground seeds; the mapgen script reads it over IPC
local storage = core.get_mod_storage()
local CYCLES_KEY = "cycles"
local SLICE_Z = str_utils.constants.slice_z
str_worldgen.CYCLE_IPC = "str_worldgen:cycles"

-- JSON keys are strings: slice z -> cycle
local raw = storage:get_string(CYCLES_KEY)
local cycles = raw ~= "" and core.parse_json(raw) or {}

-- 0.6.0 kept one counter for the only slice
local OLD_CYCLE_KEY = "cycle"
local old_cycle = storage:get_int(OLD_CYCLE_KEY)
if raw == "" and old_cycle > 0 then
	cycles[tostring(SLICE_Z)] = old_cycle
	storage:set_string(CYCLES_KEY, core.write_json(cycles))
end
storage:set_string(OLD_CYCLE_KEY, "")

local function publish()
	local by_z = {}
	for z, cycle in pairs(cycles) do
		by_z[tonumber(z)] = cycle
	end
	core.ipc_set(str_worldgen.CYCLE_IPC, by_z)
end
publish()

function str_worldgen.get_cycle(z)
	return cycles[tostring(z or SLICE_Z)] or 0
end

-- Chunks of slice z generated from now on get fresh underground content
function str_worldgen.next_cycle(z)
	local key = tostring(z or SLICE_Z)
	local cycle = (cycles[key] or 0) + 1
	cycles[key] = cycle
	storage:set_string(CYCLES_KEY, core.write_json(cycles))
	publish()
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
