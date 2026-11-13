str_inventory = {}
str_inventory.modpath = core.get_modpath(core.get_current_modname())

dofile(str_inventory.modpath .. "/table.lua")
dofile(str_inventory.modpath .. "/base.lua")
