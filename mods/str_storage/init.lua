str_storage = {}
str_storage.modpath = core.get_modpath(core.get_current_modname())

dofile(str_storage.modpath .. "/base.lua")
