st_nodes = {}
st_nodes.modpath = core.get_modpath(core.get_current_modname())

-- Also loaded by the mapgen script, so they return their tables instead of assigning them
st_nodes.shapes = dofile(st_nodes.modpath .. "/shapes.lua")
st_nodes.data = dofile(st_nodes.modpath .. "/data.lua")
dofile(st_nodes.modpath .. "/base.lua")
