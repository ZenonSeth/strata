-- While a piece item is held on foot, node-visual entities show where it would go (only to that player);
-- the _good and _bad nodes tint it green where it fits and red where it does not
local ENTITY = "str_furnish:preview"
local INTERVAL = 0.1
local DEFAULT_RANGE = 4

core.register_entity(ENTITY, {
	initial_properties = {
		visual = "node",
		node = {name = "air"},
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		selectionbox = {0, 0, 0, 0, 0, 0},
	},
})

-- player name -> {objs = {ObjectRef, ...}, key = string of the shown plan}
local previews = {}

local function hide(name)
	local preview = previews[name]
	if not preview then
		return
	end
	for _, obj in ipairs(preview.objs) do
		if obj:is_valid() then
			obj:remove()
		end
	end
	previews[name] = nil
end

local function pointed_node(player, range)
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
	local target = vector.add(eye, vector.multiply(player:get_look_dir(), range))
	for pointed in core.raycast(eye, target, false, false, str_furnish.POINTABILITIES) do
		if pointed.type == "node" then
			return pointed
		end
	end
end

local function all_valid(objs, count)
	if #objs ~= count then
		return false
	end
	for _, obj in ipairs(objs) do
		if not obj:is_valid() then
			return false
		end
	end
	return true
end

local function show(player, plan)
	local name = player:get_player_name()
	local key = ("%s|%s|%d|%s"):format(core.pos_to_string(plan.anchor), plan.variant.id, plan.param2, tostring(plan.ok))
	local preview = previews[name]
	if preview and preview.key == key and all_valid(preview.objs, #plan.cells) then
		return
	end
	hide(name)
	preview = {objs = {}, key = key}
	previews[name] = preview
	for i, pos in ipairs(plan.cells) do
		local cell = plan.variant.cells[i]
		local obj = core.add_entity(pos, ENTITY)
		if obj then
			obj:set_observers({[name] = true})
			obj:set_properties({node = {name = plan.ok and cell.good or cell.bad, param2 = plan.param2}})
			preview.objs[#preview.objs + 1] = obj
		end
	end
end

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < INTERVAL then
		return
	end
	elapsed = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local stack = player:get_wielded_item()
		local piece = str_mode.get(player) == "foot" and str_furnish.by_item[stack:get_name()]
		local plan = piece and str_furnish.plan(player, piece,
			pointed_node(player, stack:get_definition().range or DEFAULT_RANGE))
		if plan then
			show(player, plan)
		else
			hide(name)
		end
	end
end)

core.register_on_leaveplayer(function(player)
	hide(player:get_player_name())
end)
