-- First-ever spawn: each player gets their own copy of the shop/home interior in a grid in front of the
-- world, and starts on foot in the bed

str_start = {}
str_start.modpath = core.get_modpath(core.get_current_modname())

dofile(str_start.modpath .. "/base.lua")
