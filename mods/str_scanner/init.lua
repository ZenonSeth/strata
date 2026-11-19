str_scanner = {}
str_scanner.modpath = core.get_modpath(core.get_current_modname())

dofile(str_scanner.modpath .. "/base.lua")
