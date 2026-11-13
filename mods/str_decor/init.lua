str_decor = {}
str_decor.modpath = core.get_modpath(core.get_current_modname())

dofile(str_decor.modpath .. "/shapes.lua")
dofile(str_decor.modpath .. "/base.lua")
