str_interior = {}
str_interior.modpath = core.get_modpath(core.get_current_modname())

dofile(str_interior.modpath .. "/interact.lua")
dofile(str_interior.modpath .. "/base.lua")
dofile(str_interior.modpath .. "/door.lua")
dofile(str_interior.modpath .. "/lamp.lua")
dofile(str_interior.modpath .. "/furniture.lua")
dofile(str_interior.modpath .. "/home.lua")
dofile(str_interior.modpath .. "/tools.lua")
dofile(str_interior.modpath .. "/digger.lua")
