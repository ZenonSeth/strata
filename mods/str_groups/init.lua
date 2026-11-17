str_groups = {}
str_groups.modpath = core.get_modpath(core.get_current_modname())

dofile(str_groups.modpath .. "/base.lua")
