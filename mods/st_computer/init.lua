st_computer = {}
st_computer.modpath = core.get_modpath(core.get_current_modname())

dofile(st_computer.modpath .. "/base.lua")
dofile(st_computer.modpath .. "/mail.lua")
dofile(st_computer.modpath .. "/hud.lua")
