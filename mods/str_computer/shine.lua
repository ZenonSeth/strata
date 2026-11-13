local TERMINAL = "str_interior:shop_terminal"
local INTERVAL = 0.35
local RADIUS = 12
local LIFETIME = 0.6
local ANIMATION = {type = "vertical_frames", aspect_w = 9, aspect_h = 9, length = LIFETIME}

local timer = 0

local function shine(name, pos)
	core.add_particle({
		pos = vector.offset(pos, (math.random() - 0.5) * 0.7, math.random() * 0.4 - 0.1, (math.random() - 0.5) * 0.7),
		velocity = vector.new(0, 0.1 + math.random() * 0.15, 0),
		expirationtime = LIFETIME,
		size = 1.5 + math.random(),
		texture = "str_computer_shine.png",
		animation = ANIMATION,
		glow = 14,
		playername = name,
	})
end

-- Only the player with unread mail sees their own terminal sparkle
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < INTERVAL then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		if str_mail.unread_count(name) > 0 then
			local pos = player:get_pos()
			local near = core.find_nodes_in_area(
				vector.offset(pos, -RADIUS, -RADIUS, -RADIUS), vector.offset(pos, RADIUS, RADIUS, RADIUS), TERMINAL)
			for _, node_pos in ipairs(near) do
				shine(name, node_pos)
			end
		end
	end
end)
