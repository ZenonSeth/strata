str_computer = {}
str_computer.modpath = core.get_modpath(core.get_current_modname())

dofile(str_computer.modpath .. "/base.lua")
dofile(str_computer.modpath .. "/mail.lua")
dofile(str_computer.modpath .. "/hud.lua")
dofile(str_computer.modpath .. "/shine.lua")
