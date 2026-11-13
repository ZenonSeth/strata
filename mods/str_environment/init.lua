str_environment = {}
str_environment.modpath = core.get_modpath(core.get_current_modname())

dofile(str_environment.modpath .. "/lighting.lua")
dofile(str_environment.modpath .. "/vignette.lua")
dofile(str_environment.modpath .. "/sky.lua")
dofile(str_environment.modpath .. "/fog.lua")
dofile(str_environment.modpath .. "/player_lighting.lua")
dofile(str_environment.modpath .. "/clock.lua")
dofile(str_environment.modpath .. "/base.lua")
