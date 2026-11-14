local FORMNAME = "str_manual:main"
local OPEN_PREFIX = "str_manual_open_"
local TOPIC_PREFIX = "topic_"
local WIDTH, HEIGHT = 16, 12
local PAPER_X, PAPER_Y = 1.1, 1.0
local TEXT_COLOR = "#101010"
local TEXT_SIZE = 16
local WINDOW_SLICE = 32
local TAB_X, TAB_Y, TAB_W, TAB_H, TAB_GAP = WIDTH - 0.6, 1.0, 2.6, 0.9, 0.15
local TAB_SELECTED_GROW = 0.35
local TAB_SLICE = "12,8"
local TAB_TEXT_COLOR = "#161616"
local SUB_PREFIX = "sub_"
local SUB_W, SUB_H = 2.4, 0.8
local PANEL_SHADE = "#0000001c"
local PANEL_HOVER = "#0000000c"
-- Bookmark colors, handed out in page order; unselected tabs are plain grey
local TAB_COLORS = {"#e8786e", "#e8b04a", "#7cc47a", "#5fa8d8", "#b58ad8", "#e07fb0", "#58c4b8"}

-- Ordered topic list: {id = , title = , text = hypertext, color = }
local pages = {}
local page_index = {}

function str_manual.register_page(id, title, text, color)
	local page = {id = id, title = title, text = text, color = color}
	if page_index[id] then
		pages[page_index[id]] = page
	else
		pages[#pages + 1] = page
		page_index[id] = #pages
	end
end

-- Page with a row of sub-tabs: def.subtabs(player) -> {{id, title}}, def.render(player, sub_id, area) -> formspec
-- elements drawn inside the shaded panel under the row; area = {x, y, w, h}
function str_manual.register_dynamic_page(id, title, def)
	str_manual.register_page(id, title, "", def.color)
	local page = pages[page_index[id]]
	page.subtabs = def.subtabs
	page.render = def.render
end

local function fill(color)
	return core.formspec_escape("[fill:1x1:" .. color)
end

local function sub_part(player, page, sub, x, y, w, h)
	local subtabs = page.subtabs(player)
	local selected_id = subtabs[1].id
	for _, tab in ipairs(subtabs) do
		if tab.id == sub then
			selected_id = sub
		end
	end
	local fs = {}
	for i, tab in ipairs(subtabs) do
		local name = ("%s%s_%s"):format(SUB_PREFIX, page.id, tab.id)
		local selected = tab.id == selected_id
		local bg = selected and PANEL_SHADE or "#00000000"
		fs[#fs + 1] = ("style[%s;border=false;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s;textcolor=%s]"
			.. "button[%g,%g;%g,%g;%s;%s]"):format(name, fill(bg), fill(selected and PANEL_SHADE or PANEL_HOVER),
			fill(bg), TAB_TEXT_COLOR, x + (i - 1) * SUB_W, y, SUB_W, SUB_H, name, core.formspec_escape(tab.title))
	end
	local panel_y = y + SUB_H
	local area = {x = x, y = panel_y, w = w, h = h - SUB_H}
	fs[#fs + 1] = ("box[%g,%g;%g,%g;%s]"):format(area.x, area.y, area.w, area.h, PANEL_SHADE)
	fs[#fs + 1] = page.render(player, selected_id, area)
	return table.concat(fs)
end

local function tab_image(base, color)
	return core.formspec_escape(base .. (color and ("^[multiply:" .. color) or ""))
end

local function tabs_part(topic)
	local fs = {}
	local count = #pages
	-- Invisible backing so clicks in the gaps do not fall outside the window and close it
	fs[#fs + 1] = "style[tabgap;noclip=true;border=false;bgimg=" .. core.formspec_escape("[fill:1x1:#00000000") .. "]"
	fs[#fs + 1] = ("button[%g,%g;%g,%g;tabgap;]"):format(TAB_X, TAB_Y,
		TAB_W + TAB_SELECTED_GROW, count * (TAB_H + TAB_GAP))
	local selected_part
	for i, page in ipairs(pages) do
		local name = TOPIC_PREFIX .. page.id
		local y = TAB_Y + (i - 1) * (TAB_H + TAB_GAP)
		local selected = page.id == topic
		local color = page.color or TAB_COLORS[(i - 1) % #TAB_COLORS + 1]
		local bg = selected and tab_image("str_manual_bookmark.png", color) or "str_manual_bookmark.png"
		local hover = tab_image("str_manual_bookmark.png", selected and color or "#f4f4f4")
		local w = selected and TAB_W + TAB_SELECTED_GROW or TAB_W
		local part = ("style[%s;noclip=true;border=false;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s;"
			.. "bgimg_middle=%s;textcolor=%s]button[%g,%g;%g,%g;%s;%s]"):format(
			name, bg, hover, bg, TAB_SLICE, TAB_TEXT_COLOR, TAB_X, y, w, TAB_H, name,
			core.formspec_escape(page.title))
		-- The selected tab goes last so it draws over its neighbours
		if selected then
			selected_part = part
		else
			fs[#fs + 1] = part
		end
	end
	fs[#fs + 1] = selected_part
	return table.concat(fs)
end

local function build(player, topic, sub)
	local page = pages[page_index[topic]]
	local text_w = WIDTH - 2 * PAPER_X
	local content
	if page.render then
		content = sub_part(player, page, sub, PAPER_X, PAPER_Y, text_w, HEIGHT - 2 * PAPER_Y)
	else
		local body = ("<center><big><b>%s</b></big></center>\n\n%s"):format(page.title, page.text)
		content = ("hypertext[%g,%g;%g,%g;text;<global color=%s size=%d>%s]"):format(
			PAPER_X, PAPER_Y, text_w, HEIGHT - 2 * PAPER_Y, TEXT_COLOR, TEXT_SIZE, core.formspec_escape(body))
	end
	return table.concat({
		("formspec_version[8]size[%g,%g]no_prepend[]"):format(WIDTH, HEIGHT),
		("background9[0,0;%g,%g;str_manual_window.png;false;%d]"):format(WIDTH, HEIGHT, WINDOW_SLICE),
		content,
		tabs_part(topic),
	})
end

-- Per player, this session only: the last topic and each topic's last sub-tab
local last = {}

core.register_on_leaveplayer(function(player)
	last[player:get_player_name()] = nil
end)

-- topic and sub are optional; missing ones reopen where the player left off, an unknown topic the first page
function str_manual.show(player_name, topic, sub)
	local player = core.get_player_by_name(player_name)
	if not player then
		return
	end
	local state = last[player_name] or {subs = {}}
	last[player_name] = state
	topic = topic or state.topic
	if not page_index[topic or ""] then
		topic = pages[1] and pages[1].id
	end
	sub = sub or state.subs[topic]
	state.topic = topic
	state.subs[topic] = sub
	core.show_formspec(player_name, FORMNAME, build(player, topic, sub))
end

-- Formspec elements for a button that opens the manual, to drop into any window at any position
function str_manual.button(x, y, w, h, topic)
	return ("button[%g,%g;%g,%g;%s%s;Manual]"):format(x, y, w, h, OPEN_PREFIX, topic or "")
end

core.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if formname == FORMNAME then
		for _, page in ipairs(pages) do
			if fields[TOPIC_PREFIX .. page.id] then
				str_manual.show(name, page.id)
				return
			end
			if page.subtabs then
				for _, tab in ipairs(page.subtabs(player)) do
					if fields[("%s%s_%s"):format(SUB_PREFIX, page.id, tab.id)] then
						str_manual.show(name, page.id, tab.id)
						return
					end
				end
			end
		end
		return
	end
	for key in pairs(fields) do
		if key:sub(1, #OPEN_PREFIX) == OPEN_PREFIX then
			str_manual.show(name, key:sub(#OPEN_PREFIX + 1))
			return
		end
	end
end)
