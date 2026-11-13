local NOTICE_HUD = "str_computer:mail_notice"

-- Next to the clock in the upper left of the top bar
str_hud.register_text(NOTICE_HUD, {
	position = {x = 0, y = 0}, offset = {x = 210, y = 22}, size = 1.3, color = 0xFFE040, mono = true,
})

local function show_notice(player)
	local unread = str_mail.unread_count(player:get_player_name()) > 0
	str_hud.set_text(player, NOTICE_HUD, unread and "You have new mail!" or "")
end

str_mail.register_on_change(show_notice)
core.register_on_joinplayer(show_notice)
