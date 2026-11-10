st_utils = {}
st_utils.modpath = core.get_modpath(core.get_current_modname())

-- Also loaded by the mapgen script, so it returns its table instead of assigning it
st_utils.constants = dofile(st_utils.modpath .. "/constants.lua")
dofile(st_utils.modpath .. "/base.lua")
