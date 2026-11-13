st_elevators = {}
st_elevators.modpath = core.get_modpath(core.get_current_modname())

dofile(st_elevators.modpath .. "/shapes.lua")
dofile(st_elevators.modpath .. "/network.lua")
dofile(st_elevators.modpath .. "/travel.lua")
dofile(st_elevators.modpath .. "/base.lua")
