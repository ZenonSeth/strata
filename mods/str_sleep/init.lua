str_sleep = {}
str_sleep.modpath = core.get_modpath(core.get_current_modname())

dofile(str_sleep.modpath .. "/reset.lua")
dofile(str_sleep.modpath .. "/base.lua")
