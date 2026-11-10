-- First-ever spawn: each player gets their own copy of the shop/home interior in a grid in front of the
-- world, and starts on foot in the bed

st_start = {}
st_start.modpath = core.get_modpath(core.get_current_modname())

dofile(st_start.modpath .. "/base.lua")
