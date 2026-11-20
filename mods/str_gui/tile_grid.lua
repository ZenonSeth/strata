local theme = str_gui.theme
local esc = core.formspec_escape

local SCROLLBAR_W = 0.35
local GAP = 0.12
local PAD = 0.1
local NAME_LINE_H = 0.35
local STATUS_H = 0.35
local HEADER_H = 0.6
local HEADER_ICON = 0.45
local NAME_SIZE = 13
local BADGE_SIZE = 15
local DIM = "#141517a0"
local CLEAR = esc("[fill:1x1:#00000000")
local HOVER = esc("[fill:1x1:#ffffff14")
local PRESSED = esc("[fill:1x1:#00000030")

local function button_name(spec, i)
	return ("%s_%d"):format(spec.name, i)
end

-- A scrollable grid of clickable tiles (an image with a name below), split by optional section headers.
-- spec fields:
--   x, y, w, h, name (the scrollbar's name and the tile button prefix), columns, scroll (value to restore),
--   name_lines (room for the tile name, default 3)
--   entries = {{header = text, icon = texture}, {id =, item = item name or image = texture, label =,
--     tooltip =, badge =, badge_color =, status = a line below the name, status_color =, dim = bool}, ...}
--   selected = id of the highlighted tile
-- Read clicks with str_gui.tile_clicked(fields, name, entries) and the scroll with str_gui.tile_scroll.
function str_gui.tile_grid(spec)
	local view_w = spec.w - SCROLLBAR_W - GAP
	local tile_w = (view_w - (spec.columns - 1) * GAP) / spec.columns
	local image = math.min(tile_w - 0.4, 1.2)
	local status_h = 0
	for _, entry in ipairs(spec.entries) do
		if entry.status then
			status_h = STATUS_H
		end
	end
	local name_h = NAME_LINE_H * (spec.name_lines or 3)
	local tile_h = PAD + image + name_h + status_h + PAD / 2
	local names, tiles = {}, {}
	local col, y, bottom = 0, 0, 0
	for i, entry in ipairs(spec.entries) do
		if entry.header then
			if col > 0 then
				col, y = 0, y + tile_h + GAP
			end
			local text_x = 0
			if entry.icon then
				tiles[#tiles + 1] = ("image[0,%g;%g,%g;%s]"):format(y + (HEADER_H - HEADER_ICON) / 2,
					HEADER_ICON, HEADER_ICON, esc(entry.icon))
				text_x = HEADER_ICON + 0.15
			end
			tiles[#tiles + 1] = ("label[%g,%g;%g,%g;%s]"):format(text_x, y, view_w - text_x, HEADER_H, esc(entry.header))
			y = y + HEADER_H
			bottom = y
		else
			local x = col * (tile_w + GAP)
			local name = button_name(spec, i)
			names[#names + 1] = name
			local bg = entry.id == spec.selected and "str_gui_slot_hover.png" or "str_gui_slot.png"
			local image_x, image_y = x + (tile_w - image) / 2, y + PAD
			tiles[#tiles + 1] = ("image[%g,%g;%g,%g;%s;1]"):format(x, y, tile_w, tile_h, bg)
			if entry.item then
				tiles[#tiles + 1] = ("item_image[%g,%g;%g,%g;%s]"):format(image_x, image_y, image, image, entry.item)
			else
				tiles[#tiles + 1] = ("image[%g,%g;%g,%g;%s]"):format(image_x, image_y, image, image, esc(entry.image))
			end
			tiles[#tiles + 1] = ("hypertext[%g,%g;%g,%g;;<global margin=0 halign=center color=%s size=%d>%s]"):format(
				x + 0.05, image_y + image, tile_w - 0.1, name_h, entry.dim and theme.muted or theme.text, NAME_SIZE,
				esc(entry.label))
			if entry.status then
				tiles[#tiles + 1] = ("hypertext[%g,%g;%g,%g;;<global margin=0 halign=center color=%s size=%d><b>%s</b>]")
					:format(x + 0.05, image_y + image + name_h, tile_w - 0.1, STATUS_H, entry.status_color or theme.text,
					NAME_SIZE, esc(entry.status))
			end
			if entry.dim then
				tiles[#tiles + 1] = ("box[%g,%g;%g,%g;%s]"):format(image_x, image_y, image, image, DIM)
			end
			if entry.badge then
				tiles[#tiles + 1] = ("hypertext[%g,%g;%g,0.45;;<global margin=0 halign=right color=%s size=%d><b>%s</b>]")
					:format(x + PAD, y + 0.04, tile_w - 2 * PAD, entry.badge_color or theme.text, BADGE_SIZE,
					esc(entry.badge))
			end
			tiles[#tiles + 1] = ("button[%g,%g;%g,%g;%s;]"):format(x, y, tile_w, tile_h, name)
			if entry.tooltip then
				tiles[#tiles + 1] = ("tooltip[%s;%s]"):format(name, esc(entry.tooltip))
			end
			bottom = y + tile_h
			col = col + 1
			if col == spec.columns then
				col, y = 0, y + tile_h + GAP
			end
		end
	end

	local fs = {}
	if #names > 0 then
		local list = table.concat(names, ",")
		fs[#fs + 1] = ("style[%s;border=false;bgimg=%s;bgimg_middle=0;padding=0]"):format(list, CLEAR)
		fs[#fs + 1] = ("style[%s;bgimg=%s]"):format(list:gsub(",", ":hovered,") .. ":hovered", HOVER)
		fs[#fs + 1] = ("style[%s;bgimg=%s]"):format(list:gsub(",", ":pressed,") .. ":pressed", PRESSED)
	end
	local max = math.max(0, math.ceil((bottom - spec.h) * 10))
	fs[#fs + 1] = ("scroll_container[%g,%g;%g,%g;%s;vertical;0.1]"):format(spec.x, spec.y, view_w, spec.h, spec.name)
	fs[#fs + 1] = ("style_type[label;valign=center;textcolor=%s]"):format(theme.text)
	fs[#fs + 1] = table.concat(tiles)
	fs[#fs + 1] = "style_type[label;valign=top]"
	fs[#fs + 1] = "scroll_container_end[]"
	if max > 0 then
		fs[#fs + 1] = ("scrollbaroptions[min=0;max=%d;smallstep=10;largestep=%d;thumbsize=%d]"):format(
			max, math.floor(spec.h * 10), math.max(1, math.floor(max * spec.h / bottom)))
		fs[#fs + 1] = ("scrollbar[%g,%g;%g,%g;vertical;%s;%d]"):format(spec.x + spec.w - SCROLLBAR_W, spec.y,
			SCROLLBAR_W, spec.h, spec.name, math.min(spec.scroll or 0, max))
	end
	return table.concat(fs)
end

-- The id of the tile clicked in `fields`, or nil; entries must be the list the grid was built from
function str_gui.tile_clicked(fields, name, entries)
	local prefix = name .. "_"
	for key in pairs(fields) do
		local index = key:sub(1, #prefix) == prefix and tonumber(key:sub(#prefix + 1))
		local entry = index and entries[index]
		if entry and not entry.header then
			return entry.id
		end
	end
end

-- The grid's scroll value in `fields`, or nil
function str_gui.tile_scroll(fields, name)
	return fields[name] and core.explode_scrollbar_event(fields[name]).value
end
