st_transmissions = {}
st_transmissions.modpath = core.get_modpath(core.get_current_modname())

dofile(st_transmissions.modpath .. "/cipher.lua")
dofile(st_transmissions.modpath .. "/base.lua")
