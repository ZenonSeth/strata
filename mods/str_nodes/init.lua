str_nodes = {}
str_nodes.modpath = core.get_modpath(core.get_current_modname())

-- Also loaded by the mapgen script, so they return their tables instead of assigning them
str_nodes.shapes = dofile(str_nodes.modpath .. "/shapes.lua")
str_nodes.data = dofile(str_nodes.modpath .. "/data.lua")
dofile(str_nodes.modpath .. "/base.lua")
