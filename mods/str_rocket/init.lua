str_rocket = {}
str_rocket.modpath = core.get_modpath(core.get_current_modname())

dofile(str_rocket.modpath .. "/base.lua")
dofile(str_rocket.modpath .. "/site.lua")
