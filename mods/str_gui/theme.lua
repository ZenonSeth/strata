-- The one formspec theme (workshop: gunmetal panels, amber accent, rust pressed). Plain data.
local TEXT = "#e8e0d0"
local BUTTON_SLICE = 10
-- Multiplies the player's font size in every themed formspec
local FONT_SCALE = 1.15

local theme = {
	text = TEXT,
	-- Greyed-out text: locked or unavailable rows
	muted = "#7d7f84",
	-- Destructive actions and their warnings
	danger = "#e0584a",
	-- The part or item currently in use
	equipped = "#a9c9a4",
	window = "str_gui_window.png",
	window_slice = "8",
	header = "str_gui_header.png",
	header_slice = "8,6",
	header_height = 0.9,
	input = "str_gui_field.png",
	input_slice = "4",
}

-- Sent as the player's formspec prepend, so every formspec including the pause menu gets it
theme.prepend = table.concat({
	"listcolors[#00000000;#00000000;#00000000;#1f2022;" .. TEXT .. "]",
	"listimages[str_gui_slot.png;str_gui_slot_hover.png]",
	"style_type[button;border=false;bgimg=str_gui_button.png;bgimg_middle=" .. BUTTON_SLICE
		.. ";textcolor=" .. TEXT .. "]",
	"style_type[button:hovered;bgimg=str_gui_button_hover.png]",
	"style_type[button:pressed;bgimg=str_gui_button_pressed.png]",
	"style_type[*;font_size=*" .. FONT_SCALE .. "]",
	"style_type[label,field,pwdfield,textarea,tabheader;textcolor=" .. TEXT .. "]",
	-- No engine background on text inputs: draw str_gui.input_bg() behind them instead
	"style_type[field,pwdfield,textarea;border=false]",
	"tableoptions[background=#1b1c1e;highlight=#7a3f1d;highlight_text=" .. TEXT .. "]",
})

str_gui.theme = theme
