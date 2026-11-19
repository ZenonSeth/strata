str_interior_storage = {}
str_interior_storage.modpath = core.get_modpath(core.get_current_modname())

dofile(str_interior_storage.modpath .. "/base.lua")
dofile(str_interior_storage.modpath .. "/cleanup.lua")
