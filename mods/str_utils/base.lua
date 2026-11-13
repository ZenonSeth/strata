local COMMON_GROUPS = {oddly_breakable_by_hand = 1}

-- Fresh groups table for solid nodes; overrides add to or replace the common ones
function str_utils.get_common_groups(overrides)
	local groups = table.copy(COMMON_GROUPS)
	for k, v in pairs(overrides or {}) do
		groups[k] = v
	end
	return groups
end

-- 0 at min_impact_speed up to 1 at max_fall_speed (speed in nodes/s, positive)
function str_utils.impact_scale(speed)
	local c = str_utils.constants
	return math.max(0, math.min(1, (speed - c.min_impact_speed) / (c.max_fall_speed - c.min_impact_speed)))
end

function str_utils.impact_damage(speed)
	return str_utils.constants.max_fall_damage * str_utils.impact_scale(speed)
end

-- A burst of particles; scale multiplies size and speed
function str_utils.puff(pos, count, scale, texture, animated)
	for _ = 1, count do
		local lifetime = (0.5 + math.random() * 0.8) * scale
		core.add_particle({
			pos = pos,
			velocity = vector.new(
				(math.random() - 0.5) * 8 * scale, math.random() * 6 * scale, (math.random() - 0.5) * 8 * scale),
			acceleration = vector.new(0, -6, 0),
			expirationtime = lifetime,
			size = (1.5 + math.random() * 1.5) * scale,
			texture = texture,
			animation = animated and
				{type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = lifetime + 0.1} or nil,
			glow = 14,
			collisiondetection = true,
			collision_removal = true,
		})
	end
end

-- player name -> {id, job} of their current popup
local popups = {}

local function clear_popup(player_name)
	local popup = popups[player_name]
	if not popup then
		return
	end
	popup.job:cancel()
	local player = core.get_player_by_name(player_name)
	if player then
		player:hud_remove(popup.id)
	end
	popups[player_name] = nil
end

-- One short line of text mid-screen (or near the bottom); replaces any popup already showing
function str_utils.show_popup(player_name, text, time, at_bottom)
	local player = core.get_player_by_name(player_name)
	if not player then
		return
	end
	clear_popup(player_name)
	local id = player:hud_add({
		type = "text",
		position = {x = 0.5, y = at_bottom and 1 or 0.5},
		offset = {x = 0, y = at_bottom and -160 or 40},
		text = text,
		style = 1,
		alignment = {x = 0, y = 0},
		number = 0xDFDFDF,
	})
	popups[player_name] = {id = id, job = core.after(time or 3, clear_popup, player_name)}
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local popup = popups[name]
	if popup then
		popup.job:cancel()
		popups[name] = nil
	end
end)

-- Name of the interact key to show in prompts: the Aux1 button on touch, E on desktop
function str_utils.interact_key_name(player)
	local info = core.get_player_window_information(player:get_player_name())
	return (info and info.touch_controls) and "Aux1" or "E"
end
