st_consumables = {}
st_consumables.modpath = core.get_modpath(core.get_current_modname())

dofile(st_consumables.modpath .. "/items.lua")
dofile(st_consumables.modpath .. "/shop.lua")
dofile(st_consumables.modpath .. "/base.lua")
