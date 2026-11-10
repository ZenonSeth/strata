st_gui = {}
st_gui.modpath = core.get_modpath(core.get_current_modname())

dofile(st_gui.modpath .. "/theme.lua")
dofile(st_gui.modpath .. "/base.lua")
dofile(st_gui.modpath .. "/list_table.lua")
dofile(st_gui.modpath .. "/test.lua")
