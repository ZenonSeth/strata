str_gui = {}
str_gui.modpath = core.get_modpath(core.get_current_modname())

dofile(str_gui.modpath .. "/theme.lua")
dofile(str_gui.modpath .. "/base.lua")
dofile(str_gui.modpath .. "/list_table.lua")
dofile(str_gui.modpath .. "/test.lua")
