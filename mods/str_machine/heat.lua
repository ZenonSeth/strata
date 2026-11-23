local heat = {}

local BAR = "str_machine:heat"
local UPGRADE = "str_machine:hull_lava_protection"
local COOL_RATE = 2
local OVERHEAT_COLOR = 0xFF4500
local HOT = str_utils.constants.hot_rock
local PLASMA = str_machine_data.plasma

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
-- player name -> true while overheated from heat.add, until the bar cools to PLASMA.unlock_at
local locked = {}
-- fn(player) -> extra seconds of capacity on top of the lava protection's
local extra_capacity = {}

function heat.register_capacity(fn)
	extra_capacity[#extra_capacity + 1] = fn
end

-- Seconds of lava the hull can take: heat_time with lava protection fitted, else 0
local function shield_time(player)
	if not str_machine.hull_slots.has(player, UPGRADE) then
		return 0
	end
	return str_machine.stats.get(player).heat_time or 0
end

local function capacity(player)
	local total = shield_time(player)
	for _, fn in ipairs(extra_capacity) do
		total = total + fn(player)
	end
	return total
end

-- Called every machine step; in_hot = the machine is in a damaging liquid. Returns whether the hull is shielded
function heat.step(player, in_hot, dtime)
	local name = player:get_player_name()
	local shield, max = shield_time(player), capacity(player)
	local active = in_hot and shield > 0
	local level = levels[name] or 0
	if active then
		if level < shield then
			level = math.min(level + dtime, shield)
		end
	elseif holds[name] then
		holds[name] = holds[name] > dtime and holds[name] - dtime or nil
	else
		level = math.max(level - COOL_RATE * dtime, 0)
	end
	level = math.min(level, max)
	levels[name] = level > 0 and level or nil
	if locked[name] and level <= PLASMA.unlock_at * max then
		locked[name] = nil
	end
	local shield_full = active and level >= shield
	local full = locked[name] or shield_full or (max > 0 and level >= max)
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
	return active and not shield_full
end

-- Puts seconds of heat on the bar if lava protection is fitted; returns the share (0 to 1) it could not take
function heat.absorb(player, seconds)
	local name = player:get_player_name()
	local shield = shield_time(player)
	if shield <= 0 then
		return 1
	end
	local level = levels[name] or 0
	local taken = math.max(math.min(seconds, shield - level), 0)
	levels[name] = level + taken > 0 and level + taken or nil
	holds[name] = math.max(holds[name] or 0, HOT.cool_hold)
	return 1 - taken / seconds
end

-- Internal heat (the plasma torch), needs no lava protection; returns whether the machine is now overheated
function heat.add(player, seconds)
	local name = player:get_player_name()
	local max = capacity(player)
	local level = math.min((levels[name] or 0) + seconds, max)
	levels[name] = level > 0 and level or nil
	holds[name] = math.max(holds[name] or 0, PLASMA.cool_hold)
	if level >= max then
		locked[name] = true
	end
	return locked[name] == true
end

function heat.overheated(player)
	return locked[player:get_player_name()] == true
end

local function clear(name)
	levels[name] = nil
	showing[name] = nil
	holds[name] = nil
	locked[name] = nil
end

function heat.reset(player)
	clear(player:get_player_name())
	str_hud.set_bar(player, BAR, 0, 0, {hidden = true})
end

core.register_on_leaveplayer(function(player)
	clear(player:get_player_name())
end)

str_machine.heat = heat
