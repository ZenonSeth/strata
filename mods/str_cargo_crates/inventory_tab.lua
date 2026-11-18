local crates = str_cargo_crates

local esc = core.formspec_escape
local num = str_inventory.num
local theme = str_gui.theme
local unit = str_utils.constants.volume_unit
local LIMITS = str_utils.constants.cargo_crate
-- Machine centre height at the start, as the depth HUD measures it
local START_Y = str_utils.constants.surface_y + 1
local WIDTH, HEIGHT = str_inventory.WIDTH, str_inventory.HEIGHT
local X, W = 0.4, WIDTH - 0.8
local INTRO_Y, INTRO_H = str_gui.CONTENT_Y - 0.25, 0.5
local ROW_Y, ROW_H = str_gui.CONTENT_Y + 0.2, 0.7
local DESTROY_W = 2.2
local TABLE_Y = ROW_Y + ROW_H + 0.2
local TABLE_H = HEIGHT - TABLE_Y - 2.7
local CONTENTS_Y = TABLE_Y + TABLE_H + 0.2
-- Hypertext size 16 is the player's font size; this matches the theme's 1.15x labels
local TEXT_SIZE = 18
local HINT_COLOR = "#a9abb0"

-- Each text cell follows a color cell, so one row can mix text and muted pieces
local COLUMNS = "tablecolumns[" .. table.concat({
	"color", "text,padding=0.3",
	"color", "text,padding=0",
	"color", "text,align=right,width=3,padding=0.2",
	"color", "text,padding=0.6",
	"color", "text,padding=0.6",
	"color", "text,padding=0",
	"color", "text,align=right,width=3,padding=0.2",
	"color", "text,align=right,width=9,padding=2",
	"color", "text,padding=2",
}, ";") .. "]"

-- player name -> position hash of the selected crate
local selected = {}

local function hypertext_escape(text)
	return (text:gsub("[\\<>]", "\\%0"))
end

local function row_cells(crate)
	local y = crate.pos.y - START_Y
	local text, muted = theme.text, theme.muted
	return {
		muted, y > 0 and "Altitude" or "Depth",
		muted, ":",
		text, math.abs(y) .. "m",
		muted, "|",
		muted, "X",
		muted, ":",
		text, tostring(crate.pos.x),
		text, ("%s / %s %s"):format(num(crates.volume(crate.pos)), num(LIMITS.capacity), unit),
		muted, crate.private and "Private" or "Public",
	}
end

local function contents_text(items)
	local parts = {}
	for _, row in ipairs(str_inventory.rows(items)) do
		parts[#parts + 1] = ("%d<style color=%s>x</style>%s"):format(row.count, theme.muted,
			hypertext_escape(row.def.description))
	end
	return ("<style color=%s>Contains:</style> "):format(theme.muted)
		.. table.concat(parts, ("<style color=%s>,  </style>"):format(theme.muted))
end

local function build(player, name)
	local list = crates.list(name)
	local cells, index, current = {}, 0, nil
	for i, crate in ipairs(list) do
		for _, cell in ipairs(row_cells(crate)) do
			cells[#cells + 1] = esc(cell)
		end
		if core.hash_node_position(crate.pos) == selected[name] then
			index, current = i, crate
		end
	end
	local fs = {
		"style_type[label;valign=center]",
		("label[%g,%g;%g,%g;%s]"):format(X, INTRO_Y, W - DESTROY_W, INTRO_H,
			esc(core.colorize(theme.muted, "Showing all cargo crates you have placed in the world."))),
		("label[%g,%g;%g,%g;%s]"):format(X, ROW_Y, W - DESTROY_W, ROW_H,
			esc(core.colorize(theme.muted, "Crates: ") .. ("%d / %d"):format(#list, LIMITS.per_player))),
		"style_type[label;valign=top]",
		("tableoptions[border=false;background=#241e19;highlight=#7a3f1d;highlight_text=%s]"):format(theme.text),
		COLUMNS,
		("table[%g,%g;%g,%g;crates;%s;%d]"):format(X, TABLE_Y, W, TABLE_H, table.concat(cells, ","), index),
	}
	if #list == 0 then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(X + 0.3, TABLE_Y + 0.5, esc("You have no cargo crates."))
	end
	if current then
		fs[#fs + 1] = "style[crate_destroy:hovered;bgcolor=#d04030]"
		fs[#fs + 1] = ("button[%g,%g;%g,%g;crate_destroy;Destroy]"):format(X + W - DESTROY_W, ROW_Y - 0.1, DESTROY_W, ROW_H)
		fs[#fs + 1] = "tooltip[crate_destroy;Destroys the crate and everything in it]"
		fs[#fs + 1] = ("hypertext[%g,%g;%g,%g;;<global color=%s size=%d>%s]"):format(X, CONTENTS_Y, W,
			HEIGHT - CONTENTS_Y - 0.6, theme.text, TEXT_SIZE, esc(contents_text(current.items)))
	else
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(X, CONTENTS_Y + 0.3,
			esc(core.colorize(theme.muted, "Select a crate to see what is in it.")))
	end
	-- 0.9x the theme's 1.15x label size
	fs[#fs + 1] = ("style_type[label;font_size=*1.035]label[%g,%g;%s]style_type[label;font_size=*1.15]"):format(
		X, HEIGHT - 0.4, esc(core.colorize(HINT_COLOR,
		"Cargo crates are created automatically when you drop (not discard) an item.")))
	return table.concat(fs)
end

local function on_fields(player, fields)
	local name = player:get_player_name()
	if fields.crate_destroy then
		for _, crate in ipairs(crates.list(name)) do
			if core.hash_node_position(crate.pos) == selected[name] then
				for item, count in pairs(crates.destroy(crate.pos)) do
					str_transmissions.count_relic(name, item, "discarded", count)
				end
			end
		end
		selected[name] = nil
		str_inventory.refresh(player)
		return true
	end
	local event = core.explode_table_event(fields.crates or "")
	if event.type == "CHG" or event.type == "DCL" then
		local crate = crates.list(name)[event.row]
		selected[name] = crate and core.hash_node_position(crate.pos)
		str_inventory.refresh(player)
		return true
	end
end

str_inventory.register_tab({
	id = "crates", title = "Cargo Crates", tooltip = "Cargo Crates", image = "str_cargo_crates_tab.png",
	after = "equipment", build = build, on_fields = on_fields,
	on_leave = function(name)
		selected[name] = nil
	end,
})

crates.register_on_change(function(_, owner)
	local player = owner and core.get_player_by_name(owner)
	if player then
		str_inventory.refresh(player)
	end
end)
