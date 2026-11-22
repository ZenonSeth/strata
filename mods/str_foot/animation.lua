-- Plays the body's animation tracks from the server, picked from how the player moves
str_foot.TRACKS = {"idle", "jog", "sit", "lie"}

local BLEND = 0.2
-- Above 0: the engine sends stopped tracks to players who arrive later as frozen frames of priority 0
local PRIORITY = 1
local MOVING = 0.3 -- nodes per second
local JOG_NODES_PER_SECOND = 4 -- ground speed the jog matches at track speed 1
local SPEED_STEP = 0.05
local TURN_BLEND = 0.15
local SECTOR_SLACK = 0.2 -- of a sector, past its border before the body turns again
-- By eighth of a circle, clockwise from the look direction: degrees the body turns right, jog direction
-- 85, not 90: a half turn from one side to the other could swing through the back
local HEADINGS = {
	[0] = {turn = 0, jog = 1}, {turn = 45, jog = 1}, {turn = 85, jog = 1}, {turn = -45, jog = -1},
	{turn = 0, jog = -1}, {turn = 45, jog = -1}, {turn = -85, jog = 1}, {turn = -45, jog = 1},
}
-- Share of the turn per bone: the legs turn fully, the chest half, the head not at all
local TWIST = {turn = 1, torso = -0.5, head = -0.5}

-- player name -> {track, speed, turn, sector} last sent
local playing = {}
-- player name -> track held by set_pose
local held = {}

-- track nil returns to the automatic animation
function str_foot.set_pose(player, track)
	held[player:get_player_name()] = track
end

local function get_sector(velocity, yaw, last)
	local cos, sin = math.cos(yaw), math.sin(yaw)
	local ahead = velocity.z * cos - velocity.x * sin
	local right = velocity.x * cos + velocity.z * sin
	local exact = math.atan2(right, ahead) / (math.pi / 4)
	if last and math.abs((exact - last + 4) % 8 - 4) < 0.5 + SECTOR_SLACK then
		return last
	end
	return math.floor(exact + 0.5) % 8
end

-- Returns track, speed and, while jogging, the sector moved in
local function get_wanted(player, name, last_sector)
	if held[name] then
		return held[name], 1
	end
	-- On foot only a seat attaches the player
	if player:get_attach() then
		return "sit", 1
	end
	local velocity = player:get_velocity()
	local ground = math.hypot(velocity.x, velocity.z)
	if ground < MOVING then
		return "idle", 1
	end
	local sector = get_sector(velocity, player:get_look_horizontal(), last_sector)
	local speed = math.max(1, math.floor(ground / JOG_NODES_PER_SECOND / SPEED_STEP + 0.5)) * SPEED_STEP
	return "jog", speed * HEADINGS[sector].jog, sector
end

local function set_turn(player, degrees)
	for bone, share in pairs(TWIST) do
		player:set_bone_override(bone, {
			rotation = {vec = vector.new(0, math.rad(degrees * share), 0), interpolation = TURN_BLEND},
		})
	end
end

local function update(player, name)
	local last = playing[name]
	if not last then
		last = {turn = 0}
		playing[name] = last
	end
	local track, speed, sector = get_wanted(player, name, last.sector)
	local turn = sector and HEADINGS[sector].turn or 0
	last.sector = sector
	if turn ~= last.turn then
		set_turn(player, turn)
		last.turn = turn
	end
	if track ~= last.track then
		if last.track then
			player:stop_animation(last.track)
		end
		player:play_animation(track, {speed = speed, blend = BLEND, priority = PRIORITY})
	elseif speed ~= last.speed then
		player:update_animation(track, {speed = speed})
	end
	last.track, last.speed = track, speed
end

core.register_globalstep(function()
	for _, player in ipairs(core.get_connected_players()) do
		-- The body is hidden in the vehicle
		if str_mode.get(player) == "foot" then
			update(player, player:get_player_name())
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	playing[name], held[name] = nil, nil
end)
