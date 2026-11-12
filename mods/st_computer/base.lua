local computer = st_computer
local esc = core.formspec_escape

local FORMNAME = "st_computer:main"
local WIDTH, HEIGHT = 16, 12
local MARGIN = 0.5
local FRAME = 0.05
local MENU_BUTTON_W, MENU_BUTTON_H, MENU_GAP = 8, 0.7, 0.2

-- Light grey on black; flat, no theme textures
local colors = {frame = "#cfcfcf", bg = "#000000", text = "#ececec", muted = "#8c8c8c", hover = "#ffffff30", press = "#ffffff50"}
computer.colors = colors
computer.WIDTH, computer.HEIGHT, computer.MARGIN = WIDTH, HEIGHT, MARGIN
computer.CONTENT_Y = 1.3

-- screen id -> {build = fn(player, state) -> formspec elements, on_fields = fn(player, fields, state) -> true to redraw}
computer.screens = {}

-- player name -> {screen = id, ...screen data}
local states = {}

local function fill(color)
	return esc("[fill:8x8:" .. color)
end

-- A flat button with left-aligned text. Buttons only center their text, so the text is a label drawn under a
-- transparent button; the hover fill is translucent to let it show through
local TEXT_PAD = 0.3

function computer.button(x, y, w, h, name, text)
	local style = ("border=false;bgimg=%s;bgimg_middle=0"):format(fill("#00000000"))
	return table.concat({
		("label[%g,%g;%s]"):format(x + TEXT_PAD, y + h / 2, esc(text)),
		("style[%s;%s]"):format(name, style),
		("style[%s:hovered;%s;bgimg=%s]"):format(name, style, fill(colors.hover)),
		("style[%s:pressed;%s;bgimg=%s]"):format(name, style, fill(colors.press)),
		("button[%g,%g;%g,%g;%s;]"):format(x, y, w, h, name),
	})
end

local function frame(title)
	return table.concat({
		"formspec_version[8]",
		("size[%g,%g]"):format(WIDTH, HEIGHT),
		"style_type[label,button,textarea;font=mono]",
		("image[0,0;%g,%g;%s]"):format(WIDTH, HEIGHT, fill(colors.frame)),
		("image[%g,%g;%g,%g;%s]"):format(FRAME, FRAME, WIDTH - 2 * FRAME, HEIGHT - 2 * FRAME, fill(colors.bg)),
		("label[%g,0.6;%s]"):format(MARGIN, esc(title)),
		("image[%g,0.95;%g,0.03;%s]"):format(MARGIN, WIDTH - 2 * MARGIN, fill(colors.muted)),
	})
end

function computer.show(player, screen)
	local name = player:get_player_name()
	local state = states[name]
	if screen then
		state.screen = screen
	end
	core.show_formspec(name, FORMNAME,
		frame("TERMINAL") .. computer.screens[state.screen].build(player, state))
end

computer.screens.main = {
	build = function(player)
		local unread = st_mail.unread_count(player:get_player_name())
		local mail_text = unread > 0 and ("> Mail (%d unread)"):format(unread) or "> Mail"
		local y = computer.CONTENT_Y + 0.3
		return computer.button(MARGIN, y, MENU_BUTTON_W, MENU_BUTTON_H, "open_mail", mail_text)
			.. computer.button(MARGIN, y + MENU_BUTTON_H + MENU_GAP, MENU_BUTTON_W, MENU_BUTTON_H, "log_off", "> Log off")
	end,
	on_fields = function(player, fields, state)
		if fields.open_mail then
			state.screen = "mail"
			return true
		elseif fields.log_off then
			core.close_formspec(player:get_player_name(), FORMNAME)
		end
	end,
}

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local state = states[player:get_player_name()]
	if state and computer.screens[state.screen].on_fields(player, fields, state) then
		computer.show(player)
	end
end)

core.register_on_leaveplayer(function(player)
	states[player:get_player_name()] = nil
end)

st_interior.register_on_use(st_utils.constants.interact.terminal, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		states[player_name] = {screen = "main"}
		computer.show(player)
	end
end)
