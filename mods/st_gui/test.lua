-- Debug window for /guitest: the common elements on a coordinate grid, to see how the theme and the
-- formspec coordinates look on screen

local FORMNAME = "st_gui:test"
local INV = "st_gui_test"
local W, H = 14, 10
local GRID_MINOR = "#ffffff18"
local GRID_MAJOR = "#ffcc0066"

local function sample_item()
	for name in pairs(core.registered_nodes) do
		if name:sub(1, #"st_nodes:") == "st_nodes:" then
			return name
		end
	end
	return ""
end

local function grid()
	local fs = {}
	for x = 1, W - 1 do
		local major = x % 5 == 0
		fs[#fs + 1] = ("box[%d,0;%g,%d;%s]"):format(x, major and 0.03 or 0.02, H, major and GRID_MAJOR or GRID_MINOR)
	end
	for y = 1, H - 1 do
		local major = y % 5 == 0
		fs[#fs + 1] = ("box[0,%d;%d,%g;%s]"):format(y, W, major and 0.03 or 0.02, major and GRID_MAJOR or GRID_MINOR)
	end
	fs[#fs + 1] = "style_type[label;font_size=-5]"
	for x = 1, W - 1 do
		fs[#fs + 1] = ("label[%g,%g;%d]"):format(x + 0.04, H - 0.12, x)
	end
	for y = 1, H - 1 do
		fs[#fs + 1] = ("label[0.04,%g;%d]"):format(y + 0.12, y)
	end
	fs[#fs + 1] = "style_type[label;font_size=]"
	return table.concat(fs)
end

local function elements()
	local item = sample_item()
	return table.concat({
		-- Column A: buttons and inputs
		"label[0.4,1.6;Label (plain)]",
		"button[0.4,1.9;3.5,0.8;btn_normal;Button]",
		"button_exit[0.4,2.9;3.5,0.8;btn_exit;Button exit]",
		"button[0.4,3.9;3.5,0.8;btn_tip;Button with tooltip]",
		"tooltip[btn_tip;Tooltip text]",
		("item_image_button[0.4,4.9;0.8,0.8;%s;btn_item;]"):format(item),
		"image_button[1.4,4.9;0.8,0.8;st_gui_slot.png;btn_image;]",
		"checkbox[0.4,6.2;chk;Checkbox;true]",
		"dropdown[0.4,6.6;3.5,0.7;dd;One,Two,Three;1]",
		st_gui.input_bg(0.4, 7.9, 3.5, 0.7),
		"field[0.4,7.9;3.5,0.7;fld;Field;text]",
		st_gui.input_bg(0.4, 9.0, 3.5, 0.7),
		"pwdfield[0.4,9.0;3.5,0.7;pwd;Password field]",
		-- Column B: text and lists
		st_gui.input_bg(4.5, 1.9, 4.3, 1.5),
		"textarea[4.5,1.9;4.3,1.5;ta;Textarea;Some text\nwith two lines]",
		"hypertext[4.5,3.6;4.3,1.3;ht;<big>Hypertext</big> <b>bold</b> <i>italic</i> <style color=#e0a020>amber</style>]",
		"textlist[4.5,5.1;4.3,1.6;tl;Entry 1,Entry 2,Entry 3,Entry 4;1]",
		"tablecolumns[text,width=10;text,align=right]",
		"table[4.5,6.9;4.3,2.0;tb;Iron,12,Copper,5,Coal,40,Gold,1;1]",
		-- Column C: tabs, bars, slots, swatches
		"tabheader[0,0;tabs;Tab one,Tab two,Tab three;1;true;true]",
		"scrollbar[9,2.3;4.4,0.4;horizontal;sb_h;300]",
		"scrollbar[13.4,3.0;0.4,2.0;vertical;sb_v;100]",
		"box[9,3.1;4.0,0.3;#000000]",
		"box[9,3.1;2.4,0.3;#e0a020]",
		("list[detached:%s;main;9,3.8;3,2;]"):format(INV),
		"box[9,6.4;1,0.5;#e0a020]",
		"box[10.1,6.4;1,0.5;#9c5024]",
		"box[11.2,6.4;1,0.5;#2b2d30]",
		"box[12.3,6.4;1,0.5;#e8e0d0]",
		"image[9,7.2;2,1.2;st_gui_window.png]",
		"image[11.2,7.2;2,1;st_gui_button.png]",
		("item_image[9,8.6;1,1;%s]"):format(item),
	})
end

function st_gui.show_test(player_name)
	local inv = core.get_inventory({type = "detached", name = INV})
	if not inv then
		inv = core.create_detached_inventory(INV, {})
		inv:set_size("main", 8)
		local item = sample_item()
		if item ~= "" then
			inv:set_stack("main", 1, item .. " 5")
		end
	end
	core.show_formspec(player_name, FORMNAME, st_gui.header(W, H, "GUI test") .. grid() .. elements())
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local parts = {}
	for key, value in pairs(fields) do
		parts[#parts + 1] = key .. "=" .. tostring(value)
	end
	table.sort(parts)
	core.chat_send_player(player:get_player_name(), "guitest: " .. table.concat(parts, ", "))
end)
