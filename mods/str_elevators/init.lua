str_elevators = {}
str_elevators.modpath = core.get_modpath(core.get_current_modname())

dofile(str_elevators.modpath .. "/shapes.lua")
dofile(str_elevators.modpath .. "/network.lua")
dofile(str_elevators.modpath .. "/travel.lua")
dofile(str_elevators.modpath .. "/base.lua")
