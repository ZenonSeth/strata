st_gui = {}

local theme = dofile(core.get_modpath("st_gui") .. "/theme.lua")

st_gui.theme = theme

-- Opening of a themed window: version, size, window background and a title bar.
-- Content starts at y = st_gui.CONTENT_Y. Formspecs that want no theme start with no_prepend[] instead.
st_gui.CONTENT_Y = theme.header_height + 0.4

function st_gui.header(width, height, title)
	return table.concat({
		"formspec_version[8]",
		("size[%g,%g]"):format(width, height),
		("background9[0,0;%g,%g;%s;false;%s]"):format(width, height, theme.window, theme.window_slice),
		("background9[0,0;%g,%g;%s;false;%s]"):format(width, theme.header_height, theme.header, theme.header_slice),
		("label[0.4,%g;%s]"):format(theme.header_height / 2 - 0.05, core.formspec_escape(title)),
	})
end

-- Dark inset background for a field, pwdfield or textarea; put it just before the element (same rect)
function st_gui.input_bg(x, y, w, h)
	return ("background9[%g,%g;%g,%g;%s;false;%s]"):format(x, y, w, h, theme.input, theme.input_slice)
end

core.register_on_joinplayer(function(player)
	player:set_formspec_prepend(theme.prepend)
end)

dofile(core.get_modpath("st_gui") .. "/test.lua")
