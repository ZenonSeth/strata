local COMMON_GROUPS = {oddly_breakable_by_hand = 1}

-- Fresh groups table for solid nodes; overrides add to or replace the common ones
function st_utils.get_common_groups(overrides)
	local groups = table.copy(COMMON_GROUPS)
	for k, v in pairs(overrides or {}) do
		groups[k] = v
	end
	return groups
end

-- 0 at min_impact_speed up to 1 at max_fall_speed (speed in nodes/s, positive)
function st_utils.impact_scale(speed)
	local c = st_utils.constants
	return math.max(0, math.min(1, (speed - c.min_impact_speed) / (c.max_fall_speed - c.min_impact_speed)))
end

function st_utils.impact_damage(speed)
	return st_utils.constants.max_fall_damage * st_utils.impact_scale(speed)
end

-- A burst of particles; scale multiplies size and speed
function st_utils.puff(pos, count, scale, texture, animated)
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
