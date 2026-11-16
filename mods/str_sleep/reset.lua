local BLOCK = core.MAP_BLOCKSIZE
local SLICE_Z = str_utils.constants.slice_z
local SURFACE_Y = str_utils.constants.surface_y
local STOP_NODE = "str_elevators:stop"

-- Name of a connected player below ground (or riding an elevator), or nil
local function someone_below()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local pos = str_mode.get(player) == "vehicle" and str_machine.get_pos(player) or player:get_pos()
		if pos.y < SURFACE_Y or str_elevators.is_traveling(name) then
			return name
		end
	end
end

-- Regenerates everything below y = 0, lazily: each slice mapblock is redone the next time it activates.
-- Returns the new cycle, or nil and the reason it can't happen yet.
function str_sleep.reset_world()
	local below = someone_below()
	if below then
		return nil, ("Everyone must be above ground first (%s is below)."):format(below)
	end
	return str_worldgen.next_cycle()
end

-- Puts back the elevator stops inside minp..maxp, with the slice cell in front cleared
local function restore_stops(minp, maxp)
	local z = SLICE_Z + 1
	if z < minp.z or z > maxp.z then
		return
	end
	for _, entry in ipairs(str_elevators.all()) do
		if entry.x >= minp.x and entry.x <= maxp.x then
			for _, stop in ipairs(entry.net.stops) do
				if stop.y >= minp.y and stop.y <= maxp.y and stop.y < -1 then
					str_elevators.put(vector.new(entry.x, stop.y, z), STOP_NODE)
					local front = vector.new(entry.x, stop.y, SLICE_Z)
					core.set_node(front, {name = "air"})
					str_nodes.refresh_shapes(front)
				end
			end
		end
	end
end

core.register_lbm({
	name = "str_sleep:regenerate",
	label = "Regenerate the ground after a world reset",
	nodenames = {"str_nodes:liquid_stop"},
	run_at_every_load = true,
	bulk_action = function(pos_list)
		local bp = vector.floor(vector.divide(pos_list[1], BLOCK))
		local mark = bp.y < 0 and str_worldgen.block_mark(bp)
		if not mark or mark == str_worldgen.current_mark() then
			return
		end
		local minp, maxp = str_worldgen.regenerate_block(bp)
		if minp then
			restore_stops(minp, maxp)
		end
	end,
})

-- Someone who logged off underground may come back after a reset: redo their block now and free the machine's cell
core.register_on_joinplayer(function(player)
	local cell = vector.round(str_machine.get_saved_pos(player))
	if cell.y >= SURFACE_Y then
		return
	end
	core.emerge_area(cell, cell, function(_, _, calls_remaining)
		if calls_remaining > 0 then
			return
		end
		local bp = vector.floor(vector.divide(vector.new(cell.x, cell.y, SLICE_Z - 1), BLOCK))
		local mark = str_worldgen.block_mark(bp)
		if mark and mark ~= str_worldgen.current_mark() then
			local minp, maxp = str_worldgen.regenerate_block(bp)
			if minp then
				restore_stops(minp, maxp)
			end
		end
		if core.get_node(cell).name ~= "air" then
			core.set_node(cell, {name = "air"})
			str_nodes.refresh_shapes(cell)
		end
	end)
end)

-- Chunks the mapgen makes fresh (e.g. after blocks were deleted) get their stops back too
core.register_on_generated(function(minp, maxp)
	if minp.y < 0 then
		restore_stops(minp, vector.new(maxp.x, math.min(maxp.y, -1), maxp.z))
	end
end)
