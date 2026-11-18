-- Hull auto-repair upgrades: refill the hull up to the top of its current segment over time
local autorepair = {}

local STEP = 0.5
-- Seconds without hull damage before repair starts again
local DAMAGE_PAUSE = 5

local hull = str_machine.hull
local hull_slots = str_machine.hull_slots

local repairers = {}
for _, def in ipairs(hull_slots.items) do
	if def.segments then
		repairers[#repairers + 1] = def
	end
end
-- Fewest segments first: the better one wins when both are fitted
table.sort(repairers, function(a, b) return a.segments < b.segments end)

-- player name -> game time of the last hull damage; memory only
local last_damage = {}
-- player name -> segment count last sent to the hull bar
local shown_segments = {}

-- The fitted repairer def, or nil
function autorepair.get(player)
	for _, def in ipairs(repairers) do
		if hull_slots.has(player, def.name) then
			return def
		end
	end
end

-- Segment count of the fitted repairer, or nil
function autorepair.segments(player)
	local def = autorepair.get(player)
	return def and def.segments
end

hull.register_on_damage(function(player)
	last_damage[player:get_player_name()] = core.get_gametime()
end)

local function update(player, now)
	local name = player:get_player_name()
	local def = autorepair.get(player)
	local segments = def and def.segments
	if segments ~= shown_segments[name] then
		shown_segments[name] = segments
		hull.refresh(player)
	end
	if not def or str_machine.fuel.is_empty(player) or now - (last_damage[name] or -DAMAGE_PAUSE) < DAMAGE_PAUSE then
		return
	end
	local max = str_machine.stats.get(player).max_hull
	local segment = max / def.segments
	local level = hull.get(player)
	-- A level on a mark counts as a full segment
	local top = math.min(max, math.ceil(level / segment - 1e-6) * segment)
	if level > 0 and level < top then
		hull.add(player, math.min(top - level, segment / def.segment_time * STEP))
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < STEP then
		return
	end
	timer = timer - STEP
	local now = core.get_gametime()
	for _, player in ipairs(core.get_connected_players()) do
		update(player, now)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	last_damage[name] = nil
	shown_segments[name] = nil
end)

str_machine.autorepair = autorepair
