local computer = str_computer
local colors = computer.colors
local esc = core.formspec_escape
local limits = str_utils.constants.mail

local MARGIN, WIDTH, HEIGHT = computer.MARGIN, computer.WIDTH, computer.HEIGHT
local TAB_Y, TAB_W, TAB_H = 1.15, 2.5, 0.6
local LIST_Y, LIST_H, HEADER_H = TAB_Y + TAB_H + 0.2, 4.2, 0.7
local META_Y = LIST_Y + LIST_H + 0.4
local BODY_Y, BODY_H = META_Y + 0.9, 3.0
local BUTTON_W, BUTTON_H, BUTTON_GAP = 2.5, 0.6, 0.2
local BUTTON_Y = HEIGHT - BUTTON_H - 0.3
local MESSAGE_Y = BUTTON_Y - 0.4
local UNREAD_TEXT = "#ffffff"
local READ_TEXT = "#d2d2d2"
local ERROR_TEXT = "#ff8080"

local function date(time)
	return os.date("%Y-%m-%d", time)
end

local function fill(color)
	return esc("[fill:8x8:" .. color)
end

-- Newest first, so row n of the table is out[n]
local function newest_first(items)
	local out = {}
	for i = #items, 1, -1 do
		out[#out + 1] = items[i]
	end
	return out
end

local function items_for(name, folder)
	return newest_first(folder == "sent" and str_mail.list_sent(name) or str_mail.list(name))
end

local function list_elements(items, selected, folder)
	local cells = {}
	local selected_row = 0
	for i, item in ipairs(items) do
		local read = folder == "sent" or item.read
		-- The row colour beats highlight_text, so the selected row is coloured dark here
		cells[#cells + 1] = item.id == selected and colors.bg or (read and READ_TEXT or UNREAD_TEXT)
		cells[#cells + 1] = read and "" or "*"
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

-- The active tab is a solid block with dark text and does nothing when clicked
local function tab(x, name, text, active)
	if not active then
		return computer.button(x, TAB_Y, TAB_W, TAB_H, name, text)
	end
	return ("image[%g,%g;%g,%g;%s]"):format(x, TAB_Y, TAB_W, TAB_H, fill(colors.frame))
		.. ("label[%g,%g;%s]"):format(x + 0.3, TAB_Y + TAB_H / 2, esc(core.colorize(colors.bg, text)))
end

local function message_line(state)
	if state.message then
		return ("label[%g,%g;%s]"):format(MARGIN, MESSAGE_Y, esc(state.message))
	end
	return ""
end

local function selected_mail(name, state)
	if not state.selected then
		return nil
	end
	if state.folder == "sent" then
		return str_mail.get_sent(name, state.selected)
	end
	return str_mail.get(name, state.selected)
end

local function reply_address(sender)
	return sender == str_mail.JIM_SENDER and str_mail.JIM_NAME or sender
end

computer.screens.mail = {
	build = function(player, state)
		local name = player:get_player_name()
		local folder = state.folder or "inbox"
		local w = WIDTH - 2 * MARGIN
		local items = items_for(name, folder)
		local fs = {
			tab(MARGIN, "tab_inbox", "Inbox", folder == "inbox"),
			tab(MARGIN + TAB_W + BUTTON_GAP, "tab_sent", "Sent", folder == "sent"),
			list_elements(items, state.selected, folder),
		}
		local mail = selected_mail(name, state)
		if mail then
			local who = folder == "sent" and ("To: " .. mail.to) or ("From: " .. mail.from)
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, META_Y, esc(who))
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, META_Y + 0.5, esc("Subject: " .. mail.subject))
			fs[#fs + 1] = ("textarea[%g,%g;%g,%g;;;%s]"):format(MARGIN, BODY_Y, w, BODY_H, esc(mail.text))
		elseif #items == 0 then
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN + 0.3, LIST_Y + HEADER_H + 0.4,
				folder == "sent" and "No sent mail." or "No mail.")
		end
		fs[#fs + 1] = message_line(state)
		local x = MARGIN
		local function add_button(field, text)
			fs[#fs + 1] = computer.button(x, BUTTON_Y, BUTTON_W, BUTTON_H, field, text)
			x = x + BUTTON_W + BUTTON_GAP
		end
		add_button("back", "< Back")
		add_button("new", "New")
		if mail and folder == "inbox" and mail.sender then
			add_button("reply", "Reply")
		end
		if mail and (folder == "sent" or str_mail.can_delete(name, mail.id)) then
			add_button("delete", "Delete")
		end
		return table.concat(fs)
	end,
	on_fields = function(player, fields, state)
		local name = player:get_player_name()
		state.message = nil
		if fields.back then
			state.screen = "main"
			state.selected = nil
			state.folder = nil
			return true
		elseif fields.tab_inbox or fields.tab_sent then
			state.folder = fields.tab_sent and "sent" or "inbox"
			state.selected = nil
			return true
		elseif fields.new then
			state.draft = {to = "", subject = "", text = ""}
			state.screen = "compose"
			return true
		elseif fields.reply then
			local mail = selected_mail(name, state)
			if mail and mail.sender then
				local subject = mail.subject:sub(1, 4) == "Re: " and mail.subject or ("Re: " .. mail.subject)
				state.draft = {to = reply_address(mail.sender), subject = subject:sub(1, limits.subject_max), text = ""}
				state.screen = "compose"
			end
			return true
		elseif fields.delete then
			if state.selected then
				if state.folder == "sent" then
					str_mail.delete_sent(name, state.selected)
				else
					str_mail.delete(name, state.selected)
				end
				state.selected = nil
			end
			return true
		end
		local event = fields.mail_list and core.explode_table_event(fields.mail_list)
		if event and event.row > 0 and (event.type == "CHG" or event.type == "DCL") then
			local item = items_for(name, state.folder)[event.row]
			if item then
				state.selected = item.id
				if state.folder ~= "sent" then
					str_mail.mark_read(name, item.id)
				end
				return true
			end
		end
	end,
}

local LABEL_W = 2
local FIELD_X = MARGIN + LABEL_W
local FIELD_W = WIDTH - MARGIN - FIELD_X
local TO_Y = computer.CONTENT_Y
local SUBJECT_Y = TO_Y + BUTTON_H + 0.2
local COMPOSE_BODY_Y = SUBJECT_Y + BUTTON_H + 0.4
local COMPOSE_BODY_H = MESSAGE_Y - 0.4 - COMPOSE_BODY_Y

local function underline(x, y, w, h)
	return ("image[%g,%g;%g,0.03;%s]"):format(x, y + h - 0.03, w, fill(colors.muted))
end

computer.screens.compose = {
	build = function(_, state)
		local draft = state.draft
		local fs = {
			"style_type[field;font=mono]",
			"field_close_on_enter[to;false]",
			"field_close_on_enter[subject;false]",
			"style_type[label;valign=center]",
			("label[%g,%g;%g,%g;To:]"):format(MARGIN, TO_Y, LABEL_W, BUTTON_H),
			("label[%g,%g;%g,%g;Subject:]"):format(MARGIN, SUBJECT_Y, LABEL_W, BUTTON_H),
			"style_type[label;valign=top]",
			underline(FIELD_X, TO_Y, FIELD_W, BUTTON_H),
			underline(FIELD_X, SUBJECT_Y, FIELD_W, BUTTON_H),
			underline(MARGIN, COMPOSE_BODY_Y, WIDTH - 2 * MARGIN, COMPOSE_BODY_H),
			("field[%g,%g;%g,%g;to;;%s]"):format(FIELD_X, TO_Y, FIELD_W, BUTTON_H, esc(draft.to)),
			("field[%g,%g;%g,%g;subject;;%s]"):format(FIELD_X, SUBJECT_Y, FIELD_W, BUTTON_H, esc(draft.subject)),
			("textarea[%g,%g;%g,%g;text;;%s]"):format(MARGIN, COMPOSE_BODY_Y, WIDTH - 2 * MARGIN, COMPOSE_BODY_H,
				esc(draft.text)),
		}
		if state.error then
			fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, MESSAGE_Y, esc(core.colorize(ERROR_TEXT, state.error)))
		end
		fs[#fs + 1] = computer.button(MARGIN, BUTTON_Y, BUTTON_W, BUTTON_H, "cancel", "< Cancel")
		fs[#fs + 1] = computer.button(MARGIN + BUTTON_W + BUTTON_GAP, BUTTON_Y, BUTTON_W, BUTTON_H, "send", "Send")
		return table.concat(fs)
	end,
	on_fields = function(player, fields, state)
		local draft = state.draft
		draft.to = fields.to or draft.to
		draft.subject = fields.subject or draft.subject
		draft.text = fields.text or draft.text
		state.error = nil
		if fields.cancel then
			state.draft = nil
			state.screen = "mail"
			return true
		elseif fields.send then
			local ok, err = str_mail.send_from_player(player:get_player_name(), draft.to, draft.subject, draft.text)
			if ok then
				state.draft = nil
				state.screen = "mail"
				state.message = "Sent."
			else
				state.error = err
			end
			return true
		end
	end,
}
