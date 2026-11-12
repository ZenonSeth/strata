st_mail = {}
st_mail.modpath = core.get_modpath(core.get_current_modname())

st_mail.story = dofile(st_mail.modpath .. "/story.lua")(st_utils.constants)
dofile(st_mail.modpath .. "/base.lua")
