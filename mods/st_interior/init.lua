st_interior = {}
st_interior.modpath = core.get_modpath(core.get_current_modname())

dofile(st_interior.modpath .. "/interact.lua")
dofile(st_interior.modpath .. "/base.lua")
dofile(st_interior.modpath .. "/door.lua")
dofile(st_interior.modpath .. "/lamp.lua")
dofile(st_interior.modpath .. "/furniture.lua")
dofile(st_interior.modpath .. "/home.lua")
dofile(st_interior.modpath .. "/tools.lua")
dofile(st_interior.modpath .. "/digger.lua")
