str_pads = {}
str_pads.modpath = core.get_modpath(core.get_current_modname())

dofile(str_pads.modpath .. "/base.lua")
