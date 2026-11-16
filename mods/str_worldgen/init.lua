str_worldgen = {}
str_worldgen.modpath = core.get_modpath(core.get_current_modname())

dofile(str_worldgen.modpath .. "/base.lua")
dofile(str_worldgen.modpath .. "/regen.lua")
