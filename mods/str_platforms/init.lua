str_platforms = {}
str_platforms.modpath = core.get_modpath(core.get_current_modname())

dofile(str_platforms.modpath .. "/base.lua")
