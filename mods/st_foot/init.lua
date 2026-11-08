-- The engine's bare hand digs nothing; this lets it break nodes in the common groups in 1 s
core.override_item("", {
	tool_capabilities = {
		groupcaps = {
			oddly_breakable_by_hand = {times = {[1] = 1}, uses = 0, maxlevel = 1},
		},
	},
})

-- On foot: normal first person, regular player controls
st_mode.register_mode("foot", {
	on_enter = function(player)
		player:hud_set_flags({wielditem = true, crosshair = true})
	end,
})
