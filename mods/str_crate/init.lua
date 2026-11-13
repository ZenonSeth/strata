str_crate = {}
str_crate.modpath = core.get_modpath(core.get_current_modname())

dofile(str_crate.modpath .. "/base.lua")
