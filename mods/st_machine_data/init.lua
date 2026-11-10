st_machine_data = {}
st_machine_data.modpath = core.get_modpath(core.get_current_modname())

st_machine_data.bits = dofile(st_machine_data.modpath .. "/bits.lua")
st_machine_data.tanks = dofile(st_machine_data.modpath .. "/tanks.lua")
