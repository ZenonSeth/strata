str_recipes = {}
str_recipes.modpath = core.get_modpath(core.get_current_modname())

dofile(str_recipes.modpath .. "/base.lua")
