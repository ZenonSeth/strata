-- The engine's bare hand digs nothing; this lets it break nodes in the common groups in 1 s
core.override_item("", {
	tool_capabilities = {
		groupcaps = {
			oddly_breakable_by_hand = {times = {[1] = 1}, uses = 0, maxlevel = 1},
		},
	},
})

-- Invisible hand when wielding nothing
core.override_item("", {
	wield_image = "blank.png",
	wield_scale = {x = 0, y = 0, z = 0},
})

core.register_on_joinplayer(function(player)
	player:set_physics_override({speed = 1.15})
end)

-- On foot: normal first person, regular player controls
st_mode.register_mode("foot", {
	on_enter = function(player)
		player:hud_set_flags({wielditem = false, crosshair = true, hotbar = false})
		st_audio.music.play(player, "foot")
	end,
})
