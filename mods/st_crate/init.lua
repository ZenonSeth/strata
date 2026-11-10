st_crate = {}
st_crate.modpath = core.get_modpath(core.get_current_modname())

dofile(st_crate.modpath .. "/base.lua")
