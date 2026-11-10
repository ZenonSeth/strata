st_environment = {}
st_environment.modpath = core.get_modpath(core.get_current_modname())

dofile(st_environment.modpath .. "/lighting.lua")
dofile(st_environment.modpath .. "/vignette.lua")
dofile(st_environment.modpath .. "/sky.lua")
dofile(st_environment.modpath .. "/player_lighting.lua")
dofile(st_environment.modpath .. "/base.lua")
