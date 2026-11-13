local theme = str_gui.theme

-- Matches the corner size of the tab background textures
local TAB_SLICE = 4

-- Opening of a themed window: version, size, window background and a title bar.
-- Content starts at y = str_gui.CONTENT_Y. Formspecs that want no theme start with no_prepend[] instead.
str_gui.CONTENT_Y = theme.header_height + 0.4

function str_gui.header(width, height, title)
	return table.concat({
		"formspec_version[8]",
		("size[%g,%g]"):format(width, height),
		("background9[0,0;%g,%g;%s;false;%s]"):format(width, height, theme.window, theme.window_slice),
		("background9[0,0;%g,%g;%s;false;%s]"):format(width, theme.header_height, theme.header, theme.header_slice),
		("label[0.4,%g;%s]"):format(theme.header_height / 2 - 0.05, core.formspec_escape(title)),
	})
end

-- Dark inset background for a field, pwdfield or textarea; put it just before the element (same rect)
function str_gui.input_bg(x, y, w, h)
	return ("background9[%g,%g;%g,%g;%s;false;%s]"):format(x, y, w, h, theme.input, theme.input_slice)
end

-- Row (or column) of tabs, each an icon (image) or a text label over a background image. They are
-- buttons, so they can sit outside the window edge (noclip). Returns formspec elements; spec fields:
--   x, y, w, h (size of one tab), tabs = {{id=, image= or label=, tooltip=}, ...}, selected = id
--   bg, bg_selected (textures; bg_selected defaults to bg), vertical (bool), spacing (default 0.1)
--   prefix (button name prefix, default "tab_"), selected_scale (default 1.1; grows around the tab center)
-- Read clicks with str_gui.tab_clicked(fields, prefix).
function str_gui.tab_bar(spec)
	local prefix = spec.prefix or "tab_"
	local spacing = spec.spacing or 0.1
	local scale = spec.selected_scale or 1.1
	local bg_selected = spec.bg_selected or spec.bg
	local parts = {}
	local selected_part
	-- Faint backing button behind the tabs so clicks in the gaps do not fall outside the window and close it
	local count = #spec.tabs
	local pad = math.max(spec.w, spec.h) * (scale - 1) / 2
	local span_w = spec.vertical and spec.w or count * spec.w + (count - 1) * spacing
	local span_h = spec.vertical and count * spec.h + (count - 1) * spacing or spec.h
	local gap_name = "tabgap_" .. prefix
	parts[1] = table.concat({
		("style[%s,%s:hovered,%s:pressed;noclip=true;border=false;bgimg=%s]"):format(gap_name, gap_name,
			gap_name, core.formspec_escape("[fill:1x1:#00000040")),
		("button[%g,%g;%g,%g;%s;]"):format(spec.x - pad, spec.y - pad, span_w + 2 * pad, span_h + 2 * pad, gap_name),
	})
	for i, tab in ipairs(spec.tabs) do
		local name = prefix .. tab.id
		local x, y = spec.x, spec.y
		if spec.vertical then
			y = y + (i - 1) * (spec.h + spacing)
		else
			x = x + (i - 1) * (spec.w + spacing)
		end
		local w, h = spec.w, spec.h
		local is_selected = tab.id == spec.selected
		local bg = spec.bg
		if is_selected then
			x, y = x - w * (scale - 1) / 2, y - h * (scale - 1) / 2
			w, h = w * scale, h * scale
			bg = bg_selected
		end
		local button
		if tab.label then
			button = ("button[%g,%g;%g,%g;%s;%s]"):format(x, y, w, h, name, core.formspec_escape(tab.label))
		else
			-- Only image_button draws a foreground image; a plain button ignores fgimg
			button = ("image_button[%g,%g;%g,%g;%s;%s;;true;false]"):format(
				x, y, w, h, core.formspec_escape(tab.image), name)
		end
		local part = table.concat({
			("style[%s;noclip=true;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s;bgimg_middle=%d;border=false]"):format(
				name, bg, bg, bg_selected, TAB_SLICE),
			button,
			tab.tooltip and ("tooltip[%s;%s]"):format(name, core.formspec_escape(tab.tooltip)) or "",
		})
		-- Selected tab is emitted last so it draws on top of its neighbours
		if is_selected then
			selected_part = part
		else
			parts[#parts + 1] = part
		end
	end
	parts[#parts + 1] = selected_part
	return table.concat(parts)
end

-- The tab id clicked in `fields`, or nil
function str_gui.tab_clicked(fields, prefix)
	prefix = prefix or "tab_"
	for key in pairs(fields) do
		if key:sub(1, #prefix) == prefix then
			return key:sub(#prefix + 1)
		end
	end
end

core.register_on_joinplayer(function(player)
	player:set_formspec_prepend(theme.prepend)
end)
