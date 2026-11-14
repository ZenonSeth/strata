str_manual = {}
str_manual.modpath = core.get_modpath(core.get_current_modname())

dofile(str_manual.modpath .. "/base.lua")
dofile(str_manual.modpath .. "/pages.lua")
dofile(str_manual.modpath .. "/nodes.lua")
dofile(str_manual.modpath .. "/discoveries.lua")
