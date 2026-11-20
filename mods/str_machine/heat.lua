local heat = {}

local BAR = "str_machine:heat"
local UPGRADE = "str_machine:hull_lava_protection"
local COOL_RATE = 2
local OVERHEAT_COLOR = 0xFF4500
local HOT = str_utils.constants.hot_rock

str_hud.register_bar(BAR, {
	color = str_utils.constants.colors.heat, width = 500, height = 20, size = 1.1, offset = {x = 0, y = -130},
	mode = "vehicle",
})

-- player name -> seconds of heat built up; memory only
local levels = {}
-- player name -> whether the bar is shown, so an idle machine does not push HUD data every step
local showing = {}
-- player name -> seconds left before the bar may cool again after hot rock; memory only
local holds = {}

-- Called every machine step; in_hot = the machine is in a damaging liquid. Returns whether the hull is shielded
function heat.step(player, in_hot, dtime)
	local name = player:get_player_name()
	local max = str_machine.stats.get(player).heat_time or 0
	local active = in_hot and max > 0 and str_machine.hull_slots.has(player, UPGRADE)
	local level = levels[name] or 0
	if active then
		level = math.min(level + dtime, max)
	elseif holds[name] then
		holds[name] = holds[name] > dtime and holds[name] - dtime or nil
	else
		level = math.max(level - COOL_RATE * dtime, 0)
	end
	level = math.min(level, max)
	levels[name] = level > 0 and level or nil
	local full = max > 0 and level >= max
	if active or level > 0 then
		showing[name] = true
		str_hud.set_bar(player, BAR, level, max, {
			label = full and "OVERHEATED" or "Overheating",
			text_color = full and OVERHEAT_COLOR or nil, bold = full,
		})
	elseif showing[name] then
		showing[name] = nil
		str_hud.set_bar(player, BAR, 0, 0, {hidden = true})
	end
	return active and not full
end

-- Puts seconds of heat on the bar if lava protection is fitted; returns the share (0 to 1) it could not take
function heat.absorb(player, seconds)
	local name = player:get_player_name()
	local max = str_machine.stats.get(player).heat_time or 0
	if max <= 0 or not str_machine.hull_slots.has(player, UPGRADE) then
		return 1
	end
	local level = levels[name] or 0
	local taken = math.max(math.min(seconds, max - level), 0)
	levels[name] = level + taken > 0 and level + taken or nil
	holds[name] = HOT.cool_hold
	return 1 - taken / seconds
end

function heat.reset(player)
	local name = player:get_player_name()
	levels[name] = nil
	showing[name] = nil
	holds[name] = nil
	str_hud.set_bar(player, BAR, 0, 0, {hidden = true})
end

core.register_on_leaveplayer(function(player)
	levels[player:get_player_name()] = nil
	showing[player:get_player_name()] = nil
	holds[player:get_player_name()] = nil
end)

str_machine.heat = heat
