-- The one formspec theme (workshop: gunmetal panels, amber accent, rust pressed); textures come from
-- tools/gen_gui.py. Plain data.
local TEXT = "#e8e0d0"
local BUTTON_SLICE = 5
-- Multiplies the player's font size in every themed formspec
local FONT_SCALE = 1.25

local theme = {
	text = TEXT,
	-- Greyed-out text: locked or unavailable rows
	muted = "#7d7f84",
	-- The part or item currently in use
	equipped = "#a9c9a4",
	window = "st_gui_window.png",
	window_slice = "8",
	header = "st_gui_header.png",
	header_slice = "8,6",
	header_height = 0.9,
	input = "st_gui_field.png",
	input_slice = "4",
}

-- Sent as the player's formspec prepend, so every formspec including the pause menu gets it
theme.prepend = table.concat({
	"listcolors[#00000000;#00000000;#00000000;#1f2022;" .. TEXT .. "]",
	"listimages[st_gui_slot.png;st_gui_slot_hover.png]",
	"style_type[button;border=false;bgimg=st_gui_button.png;bgimg_middle=" .. BUTTON_SLICE
		.. ";textcolor=" .. TEXT .. "]",
	"style_type[button:hovered;bgimg=st_gui_button_hover.png]",
	"style_type[button:pressed;bgimg=st_gui_button_pressed.png]",
	"style_type[*;font_size=*" .. FONT_SCALE .. "]",
	"style_type[label,field,pwdfield,textarea,tabheader;textcolor=" .. TEXT .. "]",
	-- No engine background on text inputs: draw st_gui.input_bg() behind them instead
	"style_type[field,pwdfield,textarea;border=false]",
	"tableoptions[background=#1b1c1e;highlight=#7a3f1d;highlight_text=" .. TEXT .. "]",
})

st_gui.theme = theme
