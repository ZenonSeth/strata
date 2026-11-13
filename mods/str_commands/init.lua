str_commands = {}
str_commands.modpath = core.get_modpath(core.get_current_modname())

pcall(dofile, str_commands.modpath .. "/base.lua")
