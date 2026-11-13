-- Disabled: time is frozen
-- local CLOCK_HUD = "str_environment:clock"
-- local INTERVAL = 1

-- -- Upper left of the top bar; the text is a fixed width, so it is centered at a fixed spot
-- str_hud.register_text(CLOCK_HUD, {
-- 	position = {x = 0, y = 0}, offset = {x = 45, y = 22}, size = 1.3, color = 0xFFFFFF, mono = true,
-- })

-- local function clock_label()
-- 	local minutes = math.floor(core.get_timeofday() * 1440) % 1440
-- 	return ("%02d:%02d"):format(math.floor(minutes / 60), minutes % 60)
-- end

-- local timer = 0
-- core.register_globalstep(function(dtime)
-- 	timer = timer + dtime
-- 	if timer < INTERVAL then
-- 		return
-- 	end
-- 	timer = 0
-- 	local label = clock_label()
-- 	for _, player in ipairs(core.get_connected_players()) do
-- 		str_hud.set_text(player, CLOCK_HUD, label)
-- 	end
-- end)

-- core.register_on_joinplayer(function(player)
-- 	str_hud.set_text(player, CLOCK_HUD, clock_label())
-- end)
