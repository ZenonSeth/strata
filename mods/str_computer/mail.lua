local computer = str_computer
local colors = computer.colors
local esc = core.formspec_escape

local MARGIN, WIDTH = computer.MARGIN, computer.WIDTH
local LIST_Y, LIST_H, HEADER_H = computer.CONTENT_Y, 4.6, 0.7
local META_Y = LIST_Y + LIST_H + 0.4
local BODY_Y, BODY_H = META_Y + 0.9, 3.8
local BUTTON_H = 0.6
local UNREAD_TEXT = "#ffffff"
local READ_TEXT = "#d2d2d2"

local function date(time)
	return os.date("%Y-%m-%d", time)
end

-- Newest first, so row n of the table is items[n]
local function items_for(name)
	local items = str_mail.list(name)
	local out = {}
	for i = #items, 1, -1 do
		out[#out + 1] = items[i]
	end
	return out
end

local function list_elements(items, selected)
	local cells = {}
	local selected_row = 0
	for i, item in ipairs(items) do
		-- The row colour beats highlight_text, so the selected row is coloured dark here
		cells[#cells + 1] = item.id == selected and colors.bg or (item.read and READ_TEXT or UNREAD_TEXT)
		cells[#cells + 1] = item.read and "" or "*"
		cells[#cells + 1] = date(item.time)
		cells[#cells + 1] = esc(item.subject)
		if item.id == selected then
			selected_row = i
		end
	end
	local specs = "text,width=1;text,width=7;text,width=14"
	local w = WIDTH - 2 * MARGIN
	local options = "tableoptions[border=false;background=%s;highlight=%s;highlight_text=%s]"
	return table.concat({
		options:format(colors.bg, colors.bg, colors.muted),
		"tablecolumns[" .. specs .. "]",
		("table[%g,%g;%g,%g;mail_header;,Date,Subject;0]"):format(MARGIN, LIST_Y, w, HEADER_H),
		options:format(colors.bg, colors.text, colors.bg),
		("tablecolumns[color,span=3;%s]"):format(specs),
		("table[%g,%g;%g,%g;mail_list;%s;%d]"):format(MARGIN, LIST_Y + HEADER_H, w, LIST_H - HEADER_H,
			table.concat(cells, ","), selected_row),
	})
end

computer.screens.mail = {
	build = function(player, state)
		local name = player:get_player_name()
		local w = WIDTH - 2 * MARGIN
		local fs = {list_elements(items_for(name), state.selected)}
		local mail = state.selected and str_mail.get(name, state.selected)
		if mail then
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, META_Y, esc("From: " .. mail.from))
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, META_Y + 0.5, esc("Subject: " .. mail.subject))
			fs[#fs + 1] = ("textarea[%g,%g;%g,%g;;;%s]"):format(MARGIN, BODY_Y, w, BODY_H, esc(mail.text))
		elseif #str_mail.list(name) == 0 then
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN + 0.3, LIST_Y + HEADER_H + 0.4, "No mail.")
		end
		fs[#fs + 1] = computer.button(MARGIN, computer.HEIGHT - BUTTON_H - 0.3, 3, BUTTON_H, "back", "< Back")
		return table.concat(fs)
	end,
	on_fields = function(player, fields, state)
		if fields.back then
			state.screen = "main"
			state.selected = nil
			return true
		end
		local event = fields.mail_list and core.explode_table_event(fields.mail_list)
		if event and event.row > 0 and (event.type == "CHG" or event.type == "DCL") then
			local name = player:get_player_name()
			local item = items_for(name)[event.row]
			if item then
				state.selected = item.id
				str_mail.mark_read(name, item.id)
				return true
			end
		end
	end,
}
