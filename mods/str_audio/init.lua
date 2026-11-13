str_audio = {
	music = {},
	sfx = {},
}
str_audio.modpath = core.get_modpath(core.get_current_modname())

dofile(str_audio.modpath .. "/base.lua")
