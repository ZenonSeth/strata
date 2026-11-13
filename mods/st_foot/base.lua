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

-- Model frames (seconds): idle pose at 0, walk cycle 1-2. Idle needs a non-empty range or the engine
-- never restarts the walk. One walk cycle covers NODES_PER_CYCLE nodes of travel.
local PHYSICS_SPEED = 1.15
local WALK_BASE_SPEED = 4 -- engine movement_speed_walk
local NODES_PER_CYCLE = 3.0
local WALK_RANGE = {x = 1, y = 2}
local IDLE_RANGE = {x = 0, y = 0.01}

core.register_on_joinplayer(function(player)
	player:set_physics_override({speed = PHYSICS_SPEED})
	player:set_local_animation(IDLE_RANGE, WALK_RANGE, IDLE_RANGE, WALK_RANGE,
		WALK_BASE_SPEED * PHYSICS_SPEED / NODES_PER_CYCLE)
	player:set_properties({
		visual = "mesh",
		mesh = "st_foot_player.glb",
		textures = {"st_foot_player.png"},
		visual_size = {x = 1, y = 1, z = 1},
		eye_height = 1.62,
	})
end)

-- On foot: normal first person, regular player controls
st_mode.register_mode("foot", {
	on_enter = function(player)
		player:set_camera({mode = "first"})
		player:hud_set_flags({wielditem = false, crosshair = true, hotbar = false})
		st_audio.music.play(player, "foot")
	end,
})
