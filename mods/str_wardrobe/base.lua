-- The wardrobe window: a turnable preview and tabs; every click is saved at once (str_foot.set_look)
local FORMNAME = "str_wardrobe:main"
local esc = core.formspec_escape
local theme = str_gui.theme

local WIDTH, HEIGHT = 15, 10.4
local PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H = 0.4, str_gui.CONTENT_Y, 5, 8.7
local PANEL_X = PREVIEW_X + PREVIEW_W + 0.4
local PANEL_W = WIDTH - PANEL_X - 0.4
local TAB_H = 0.8
local COLUMNS, BUTTON_H, BUTTON_GAP = 3, 0.8, 0.2
local SWATCH, SWATCH_GAP = 0.6, 0.15
local LABEL_H, SECTION_GAP = 0.45, 0.25
-- About the mean of the grey layers, so a swatch shows the colour the body gets
local LAYER_GREY = "#dcdcdc"

local SKIN = {"#f3d5bd", "#e8c0a0", "#ddaa86", "#cdac85", "#b07850", "#8d5a3c", "#6a4430", "#4a2e20"}
local HAIR = {"#1a1714", "#3a2a20", "#4b321e", "#604028", "#9a6a3a", "#c8a060", "#e0c890", "#a03020",
	"#d0d0d0", "#606060", "#2a4a8a", "#a02080"}
local CLOTH = {"#f0f0ec", "#b3b3b3", "#606366", "#2a2b2e", "#7a2a24", "#b05434", "#d0a030", "#6a7a3a",
	"#3e5a32", "#2e5a5a", "#465470", "#202a44", "#5a3a6e", "#756442", "#5c4f35", "#3a322e"}

local TABS = {
	{id = "body", label = "Body",
		style = {field = "body", title = "Body type",
			options = {{id = "male", label = "Male"}, {id = "female", label = "Female"}}},
		colour = {key = "skin", title = "Skin tone", palette = SKIN}},
	{id = "hair", label = "Hair",
		style = {field = "hair", title = "Style",
			options = {{id = "short", label = "Short"}, {id = "long", label = "Long"}}},
		extras = {{field = "ponytail", label = "Ponytail"},
			{field = "beard", label = "Beard", allowed = str_foot.can_have_beard}},
		colour = {key = "hair", title = "Hair colour", palette = HAIR}},
	{id = "top", label = "Top",
		style = {field = "top", title = "Style",
			options = {{id = "short", label = "Short sleeves"}, {id = "long", label = "Long sleeves"}}},
		colour = {key = "top", title = "Colour", palette = CLOTH}},
	{id = "bottom", label = "Bottom",
		style = {field = "bottom", title = "Style",
			options = {{id = "short", label = "Shorts"}, {id = "long", label = "Long pants"}}},
		colour = {key = "bottom", title = "Colour", palette = CLOTH}},
	{id = "shoes", label = "Shoes",
		colour = {key = "shoes", title = "Colour", palette = CLOTH}},
}
local TAB_BY_ID = {}
for _, tab in ipairs(TABS) do
	TAB_BY_ID[tab.id] = tab
end

-- player name -> open tab
local open_tab = {}

local function get_tab(name)
	return open_tab[name] or TABS[1]
end

local function get_extras(tab, look)
	local list = {}
	for _, extra in ipairs(tab.extras or {}) do
		if not extra.allowed or extra.allowed(look) then
			list[#list + 1] = extra
		end
	end
	return list
end

local function preview(look)
	local mesh, textures = str_foot.get_model(look)
	for i, texture in ipairs(textures) do
		textures[i] = esc(texture)
	end
	-- Frame loop given, as the default range is not clamped to the track; idle is a still pose
	return str_gui.input_bg(PREVIEW_X, PREVIEW_Y, PREVIEW_W, PREVIEW_H)
		.. ("model[%g,%g;%g,%g;preview;%s;%s;0,180;false;true;0,0;0]"):format(PREVIEW_X, PREVIEW_Y,
			PREVIEW_W, PREVIEW_H, mesh, table.concat(textures, ","))
end

local function heading(y, text)
	return ("label[%g,%g;%s]"):format(PANEL_X, y + LABEL_H / 2, esc(text))
end

-- A row of buttons from {name, label, selected}
local function button_row(y, buttons)
	local w = (PANEL_W - (COLUMNS - 1) * BUTTON_GAP) / COLUMNS
	local fs = {}
	for i, button in ipairs(buttons) do
		if button.selected then
			fs[#fs + 1] = ("style[%s,%s:hovered;bgimg=str_gui_button_pressed.png;textcolor=%s]"):format(
				button.name, button.name, theme.equipped)
		end
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(PANEL_X + (i - 1) * (w + BUTTON_GAP), y, w, BUTTON_H,
			button.name, esc(button.label))
	end
	return table.concat(fs)
end

local function swatches(y, colour, current)
	local per_row = math.floor((PANEL_W + SWATCH_GAP) / (SWATCH + SWATCH_GAP))
	local fs = {}
	for i, hex in ipairs(colour.palette) do
		local x = PANEL_X + (i - 1) % per_row * (SWATCH + SWATCH_GAP)
		local sy = y + math.floor((i - 1) / per_row) * (SWATCH + SWATCH_GAP)
		if hex == current then
			fs[#fs + 1] = ("box[%g,%g;%g,%g;%s]"):format(x - 0.07, sy - 0.07, SWATCH + 0.14, SWATCH + 0.14,
				theme.equipped)
		end
		local name = ("sw_%s_%d"):format(colour.key, i)
		local image = esc(("[fill:8x8:%s^[multiply:%s"):format(hex, LAYER_GREY))
		fs[#fs + 1] = ("style[%s,%s:hovered,%s:pressed;bgimg=%s;bgimg_middle=0]"):format(name, name, name, image)
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;]"):format(x, sy, SWATCH, SWATCH, name)
	end
	return table.concat(fs)
end

local function panel(tab, look)
	local fs = {}
	local y = str_gui.CONTENT_Y
	local function add_buttons(title, buttons)
		fs[#fs + 1] = heading(y, title)
		fs[#fs + 1] = button_row(y + LABEL_H + 0.1, buttons)
		y = y + LABEL_H + 0.1 + BUTTON_H + SECTION_GAP
	end
	local style = tab.style
	if style then
		local buttons = {}
		for i, option in ipairs(style.options) do
			buttons[i] = {name = "opt_" .. style.field .. "_" .. option.id, label = option.label,
				selected = look[style.field] == option.id}
		end
		add_buttons(style.title, buttons)
	end
	local extras = get_extras(tab, look)
	if #extras > 0 then
		local buttons = {}
		for i, extra in ipairs(extras) do
			buttons[i] = {name = "toggle_" .. extra.field, label = extra.label, selected = look[extra.field]}
		end
		add_buttons("Extras", buttons)
	end
	fs[#fs + 1] = heading(y, tab.colour.title)
	fs[#fs + 1] = swatches(y + LABEL_H + 0.1, tab.colour, look.colours[tab.colour.key])
	return table.concat(fs)
end

local function build(player)
	local tab = get_tab(player:get_player_name())
	local look = str_foot.get_look(player)
	return table.concat({
		str_gui.header(WIDTH, HEIGHT, "Wardrobe"),
		str_gui.tab_bar({
			x = PANEL_X, y = -TAB_H, w = PANEL_W / #TABS, h = TAB_H, selected_scale = 1, spacing = 0,
			tabs = TABS, selected = tab.id, prefix = "wtab_",
			bg = "str_upgrades_tab_bg.png", bg_selected = "str_upgrades_tab_bg_sel.png",
		}),
		preview(look),
		panel(tab, look),
	})
end

local function show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

-- Applies the click to look; true if that changed it
local function apply_click(look, tab, fields)
	local style = tab.style
	if style then
		for _, option in ipairs(style.options) do
			if fields["opt_" .. style.field .. "_" .. option.id] and look[style.field] ~= option.id then
				look[style.field] = option.id
				return true
			end
		end
	end
	for _, extra in ipairs(get_extras(tab, look)) do
		if fields["toggle_" .. extra.field] then
			look[extra.field] = not look[extra.field]
			return true
		end
	end
	local key = tab.colour.key
	for i, hex in ipairs(tab.colour.palette) do
		if fields[("sw_%s_%d"):format(key, i)] and look.colours[key] ~= hex then
			look.colours[key] = hex
			return true
		end
	end
	return false
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return false
	end
	local name = player:get_player_name()
	if fields.quit then
		open_tab[name] = nil
		return true
	end
	local clicked = str_gui.tab_clicked(fields, "wtab_")
	if clicked then
		-- The client can send any name
		local tab = TAB_BY_ID[clicked]
		if tab and tab ~= get_tab(name) then
			open_tab[name] = tab
			show(player)
		end
		return true
	end
	local look = str_foot.get_look(player)
	-- Shown again only on a change, as that resets the preview's rotation
	if apply_click(look, get_tab(name), fields) then
		str_foot.set_look(player, look)
		show(player)
	end
	return true
end)

str_interior.register_on_use(str_utils.constants.interact.wardrobe, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		show(player)
	end
end)

core.register_on_leaveplayer(function(player)
	open_tab[player:get_player_name()] = nil
end)
