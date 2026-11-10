st_audio = {
	music = {},
	sfx = {},
}
st_audio.modpath = core.get_modpath(core.get_current_modname())

dofile(st_audio.modpath .. "/base.lua")
