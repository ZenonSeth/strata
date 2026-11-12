st_commands = {}
st_commands.modpath = core.get_modpath(core.get_current_modname())

pcall(dofile, st_commands.modpath .. "/base.lua")
