local SLICE_Z = str_utils.constants.slice_z

-- Nodes per second of the virtual ride, the shortest ride, the fade to black, and how long to wait for the map
local SPEED = 300
local MIN_TIME = 2
local FADE = 0.6
local MAP_TIMEOUT = 15
local EMERGE_RADIUS = vector.new(16, 16, 16)

str_audio.sfx.register("elevator_loop", {sound = "str_elevators_loop"})
str_audio.sfx.register("elevator_ding", {sound = "str_elevators_ding"})

-- player name -> {phase = "in" | "wait", t, duration, dest, ready, arrived, hud, alpha}
local trips = {}

function str_elevators.is_traveling(player_name)
	return trips[player_name] ~= nil
end

local function set_alpha(player, trip, alpha)
	local value = math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5)
	if value ~= trip.alpha then
		trip.alpha = value
		player:hud_change(trip.hud, "text", "[fill:8x8:#000000^[opacity:" .. value)
	end
end

-- Fades to black, moves the machine once the map is there, waits the ride time and cuts the black away
function str_elevators.travel(player, x, from_y, to_y)
	str_elevators.travel_to(player, vector.new(x, to_y, SLICE_Z), math.abs(to_y - from_y))
end

-- Same ride to any dest cell; distance is the length of the ride in nodes
function str_elevators.travel_to(player, dest, distance)
	local name = player:get_player_name()
	if trips[name] then
		return
	end
	local trip = {
		phase = "in", t = 0, dest = dest, ready = false,
		duration = math.max(MIN_TIME, distance / SPEED),
		hud = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = -100, y = -100}, text = "[fill:8x8:#000000^[opacity:0", z_index = 1000,
		}),
		alpha = 0,
	}
	core.emerge_area(vector.subtract(dest, EMERGE_RADIUS), vector.add(dest, EMERGE_RADIUS),
		function(_, _, calls_remaining)
			if calls_remaining == 0 then
				trip.ready = true
			end
		end)
	str_machine.set_frozen(player, true)
	str_audio.sfx.start_loop(player, "elevator", "elevator_loop")
	trips[name] = trip
end

-- The machine arrives in an empty cell whatever was there
local function clear(pos)
	if core.get_node(pos).name ~= "air" then
		core.set_node(pos, {name = "air"})
	end
end

local function finish(player, name, trip)
	player:hud_remove(trip.hud)
	str_machine.set_frozen(player, false)
	str_audio.sfx.stop_loop(player, "elevator")
	trips[name] = nil
end

core.register_globalstep(function(dtime)
	for name, trip in pairs(trips) do
		local player = core.get_player_by_name(name)
		if not player then
			trips[name] = nil
		else
			trip.t = trip.t + dtime
			if trip.phase == "in" then
				set_alpha(player, trip, trip.t / FADE)
				if trip.t >= FADE then
					trip.phase, trip.t = "wait", 0
				end
			elseif trip.phase == "wait" then
				if not trip.arrived and trip.ready then
					-- Moved while black, so the ground there loads (and regenerates) during the ride
					clear(trip.dest)
					str_machine.teleport(player, trip.dest)
					trip.arrived = true
				end
				local timed_out = trip.t >= trip.duration + MAP_TIMEOUT
				if trip.arrived and (timed_out or trip.t >= trip.duration
						and core.compare_block_status(trip.dest, "active")) then
					clear(trip.dest)
					str_audio.sfx.stop_loop(player, "elevator")
					str_audio.sfx.play("elevator_ding", {player = player})
					finish(player, name, trip)
				elseif timed_out then
					finish(player, name, trip)
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	trips[player:get_player_name()] = nil
end)
