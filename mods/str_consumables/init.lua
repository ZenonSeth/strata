str_consumables = {}
str_consumables.modpath = core.get_modpath(core.get_current_modname())

dofile(str_consumables.modpath .. "/items.lua")
dofile(str_consumables.modpath .. "/shop.lua")
dofile(str_consumables.modpath .. "/base.lua")
