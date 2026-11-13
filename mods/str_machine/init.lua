str_machine = {}
str_machine.modpath = core.get_modpath(core.get_current_modname())

dofile(str_machine.modpath .. "/colors.lua")
dofile(str_machine.modpath .. "/stats.lua")
dofile(str_machine.modpath .. "/cargo.lua")

for _, item in ipairs(str_materials.list) do
	str_machine.cargo.register_item(item.name, {volume = item.volume, weight = item.weight})
end

dofile(str_machine.modpath .. "/gauge.lua")
dofile(str_machine.modpath .. "/fuel.lua")
dofile(str_machine.modpath .. "/hull.lua")
dofile(str_machine.modpath .. "/base.lua")
