local FORMNAME = "str_sleep:bed"
local FADE = 0.6
-- Seconds of black between falling asleep and waking up on the bed
local NIGHT = 2
local PAD = 0.6
local WIDTH = 9
local TEXT_H = 2.2
local BUTTON_W, BUTTON_H, BUTTON_GAP = 3, 0.8, 0.4
local MESSAGE_Y = str_gui.CONTENT_Y + TEXT_H + 0.3
local HEIGHT = MESSAGE_Y + 0.5 + BUTTON_H + 0.4
local TEXT = "Sleep until morning?\n\nThe ground below the surface regenerates: dug tunnels and anything left "
	.. "in the ground are gone. Elevator stops and waypoints stay."

local esc = core.formspec_escape

-- player name -> result line shown in the window
local messages = {}
-- player name -> {phase = "out" | "night" | "in", t, alpha, hud} while asleep
local sleepers = {}

local function show(name)
	local left = (WIDTH - 2 * BUTTON_W - BUTTON_GAP) / 2
	local buttons_y = HEIGHT - BUTTON_H - 0.4
	local fs = {
		str_gui.header(WIDTH, HEIGHT, "Bed"),
		("textarea[%g,%g;%g,%g;;;%s]"):format(PAD, str_gui.CONTENT_Y, WIDTH - 2 * PAD, TEXT_H, esc(TEXT)),
		("label[%g,%g;%s]"):format(PAD, MESSAGE_Y, esc(messages[name] or "")),
		("button[%g,%g;%g,%g;sleep;Sleep]"):format(left, buttons_y, BUTTON_W, BUTTON_H),
		("button_exit[%g,%g;%g,%g;cancel;Cancel]"):format(left + BUTTON_W + BUTTON_GAP, buttons_y, BUTTON_W, BUTTON_H),
	}
	core.show_formspec(name, FORMNAME, table.concat(fs))
end

str_interior.register_on_use(str_utils.constants.interact.sleep, function(player_name)
	if sleepers[player_name] then
		return
	end
	messages[player_name] = nil
	show(player_name)
end)

local function set_fade(player, trip, alpha)
	local value = math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5)
	if value ~= trip.alpha then
		trip.alpha = value
		player:hud_change(trip.hud, "text", "[fill:8x8:#000000^[opacity:" .. value)
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	if fields.quit or not fields.sleep then
		messages[name] = nil
		return
	end
	if sleepers[name] then
		return
	end
	local cycle, problem = str_sleep.reset_world()
	if not cycle then
		messages[name] = problem
		show(name)
		return
	end
	messages[name] = nil
	core.close_formspec(name, FORMNAME)
	sleepers[name] = {phase = "out", t = 0, alpha = 0, hud = player:hud_add({
		type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
		scale = {x = -100, y = -100}, text = "[fill:8x8:#000000^[opacity:0", z_index = 1000,
	})}
end)

core.register_globalstep(function(dtime)
	for name, trip in pairs(sleepers) do
		local player = core.get_player_by_name(name)
		if not player then
			sleepers[name] = nil
		else
			trip.t = trip.t + dtime
			if trip.phase == "out" then
				set_fade(player, trip, trip.t / FADE)
				if trip.t >= FADE then
					trip.phase, trip.t = "night", 0
					str_start.place_on_bed(player)
				end
			elseif trip.phase == "night" then
				if trip.t >= NIGHT then
					trip.phase, trip.t = "in", 0
				end
			else
				set_fade(player, trip, 1 - trip.t / FADE)
				if trip.t >= FADE then
					player:hud_remove(trip.hud)
					sleepers[name] = nil
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	messages[name], sleepers[name] = nil, nil
end)
