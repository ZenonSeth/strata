str_furnish = {}
str_furnish.modpath = core.get_modpath(core.get_current_modname())

dofile(str_furnish.modpath .. "/base.lua")
dofile(str_furnish.modpath .. "/preview.lua")
dofile(str_furnish.modpath .. "/table_saw.lua")
