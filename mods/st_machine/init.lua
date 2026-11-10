st_machine = {}
st_machine.modpath = core.get_modpath(core.get_current_modname())

dofile(st_machine.modpath .. "/colors.lua")
dofile(st_machine.modpath .. "/stats.lua")
dofile(st_machine.modpath .. "/cargo.lua")

for _, item in ipairs(st_materials.list) do
	st_machine.cargo.register_item(item.name, {volume = item.volume, weight = item.weight})
end

dofile(st_machine.modpath .. "/gauge.lua")
dofile(st_machine.modpath .. "/fuel.lua")
dofile(st_machine.modpath .. "/hull.lua")
dofile(st_machine.modpath .. "/base.lua")
