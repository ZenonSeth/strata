str_cargo_crates = {}
str_cargo_crates.modpath = core.get_modpath(core.get_current_modname())

dofile(str_cargo_crates.modpath .. "/base.lua")
dofile(str_cargo_crates.modpath .. "/window.lua")
dofile(str_cargo_crates.modpath .. "/inventory_tab.lua")
