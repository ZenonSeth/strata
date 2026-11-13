str_transmissions = {}
str_transmissions.modpath = core.get_modpath(core.get_current_modname())

dofile(str_transmissions.modpath .. "/cipher.lua")
dofile(str_transmissions.modpath .. "/base.lua")
