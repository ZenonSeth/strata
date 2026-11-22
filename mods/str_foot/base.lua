-- Invisible hand when wielding nothing
core.override_item("", {
	wield_image = "blank.png",
	wield_scale = {x = 0, y = 0, z = 0},
})

local PHYSICS_SPEED = 1.15

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
	local mesh, textures = str_foot.get_model(str_foot.get_look(player))
	player:set_properties({
		visual = "mesh",
		mesh = mesh,
		textures = textures,
		-- Players default to no culling, which shows the inside of the hair shell
		backface_culling = true,
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
