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

-- In the vehicle the body is hidden from others. Zero size, as the engine resends players with
-- is_visible forced on; a nametag color with alpha 0 removes the nametag
local function update_body(player, mode)
	local on_foot = mode == "foot"
	local size = on_foot and 1 or 0
	player:set_properties({visual_size = {x = size, y = size, z = size}})
	player:set_nametag_attributes({color = {a = on_foot and 255 or 0, r = 255, g = 255, b = 255}})
end

core.register_on_joinplayer(function(player)
	player:set_physics_override({speed = PHYSICS_SPEED})
	player:set_local_animation(IDLE_RANGE, WALK_RANGE, IDLE_RANGE, WALK_RANGE,
		WALK_BASE_SPEED * PHYSICS_SPEED / NODES_PER_CYCLE)
	player:set_properties({
		visual = "mesh",
		mesh = "str_foot_player.glb",
		textures = {"str_foot_player.png"},
		eye_height = 1.62,
	})
	update_body(player, str_mode.get(player))
end)

str_mode.register_on_change(update_body)

-- On foot: normal first person, regular player controls
str_mode.register_mode("foot", {
	on_enter = function(player)
		player:set_camera({mode = "first"})
		player:hud_set_flags({wielditem = false, crosshair = true, hotbar = true})
		str_audio.music.play(player, "foot")
	end,
})
