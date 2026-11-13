str_utils = {}
str_utils.modpath = core.get_modpath(core.get_current_modname())

-- Also loaded by the mapgen script, so it returns its table instead of assigning it
str_utils.constants = dofile(str_utils.modpath .. "/constants.lua")
dofile(str_utils.modpath .. "/base.lua")
