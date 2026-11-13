str_mail = {}
str_mail.modpath = core.get_modpath(core.get_current_modname())

str_mail.story = dofile(str_mail.modpath .. "/story.lua")(str_utils.constants)
dofile(str_mail.modpath .. "/base.lua")
