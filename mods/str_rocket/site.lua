-- Placing a blueprint: in surface mode, point at the ground (like the scanner) to see a green or red preview,
-- left click to confirm, and fence nodes mark out the site for good
local constants = str_utils.constants
local SURFACE_Y = constants.surface_y
local MIN_Z = constants.slice_z + 2
local MAX_Z = constants.slice_z + constants.back_depth
local HALF_WIDTH = constants.world_half_width
local POINT_RANGE = 24
local INTERVAL = 0.1
local CROSSHAIR = "str_lasers_crosshair.png^[multiply:#a8ecff"
local PREVIEW = "str_rocket:preview"
local INNER = "str_rocket:site_inner"
local FORM = "str_rocket:confirm"
local GOOD_TINT, BAD_TINT = "#40e040", "#e04040"
local WOBBLE_SPEED, WOBBLE_SIZE = 5, 0.04

-- kind -> cells as {x, z} offsets from the pointed ground node, and the window title
local FOOTPRINTS = {
	site = {title = "rocket site", cells = {}},
	support = {title = "launch workshop", cells = {{0, 0}, {1, 0}}},
}
for x = -1, 1 do
	for z = -1, 1 do
		table.insert(FOOTPRINTS.site.cells, {x, z})
	end
end

-- Fence nodes: one per set of outer sides of a cell (n = +z, e = +x, s = -z, w = -x)
local SIDE_ORDER = {"n", "e", "s", "w"}
local SIDE_DIRS = {n = {0, 1}, e = {1, 0}, s = {0, -1}, w = {-1, 0}}
local LINE = 0.5 - 1.5 / 16
local RAILS = {{-0.5 + 4 / 16, -0.5 + 5.5 / 16}, {-0.5 + 8 / 16, -0.5 + 9.5 / 16}}
local POST_TOP = -0.5 + 11 / 16
local P, R = 1 / 16, 0.5 / 16

local function fence_boxes(sides)
	local boxes = {}
	local function post(x, z)
		boxes[#boxes + 1] = {x - P, -0.5, z - P, x + P, POST_TOP, z + P}
	end
	for side in pairs(sides) do
		local d = SIDE_DIRS[side]
		-- Along the side, a rail stops at the fence line of a neighbouring outer side
		local lo_side, hi_side = d[1] == 0 and "w" or "s", d[1] == 0 and "e" or "n"
		local lo, hi = sides[lo_side] and -LINE or -0.5, sides[hi_side] and LINE or 0.5
		for _, rail in ipairs(RAILS) do
			if d[1] == 0 then
				local z = d[2] * LINE
				boxes[#boxes + 1] = {lo, rail[1], z - R, hi, rail[2], z + R}
			else
				local x = d[1] * LINE
				boxes[#boxes + 1] = {x - R, rail[1], lo, x + R, rail[2], hi}
			end
		end
		post(d[1] * LINE, d[2] * LINE)
		for end_side, sign in pairs({[lo_side] = -1, [hi_side] = 1}) do
			if sides[end_side] then
				post(d[1] == 0 and sign * LINE or d[1] * LINE, d[1] == 0 and d[2] * LINE or sign * LINE)
			end
		end
	end
	return boxes
end

local function fence_name(sides)
	local key = ""
	for _, side in ipairs(SIDE_ORDER) do
		key = key .. (sides[side] and side or "")
	end
	return "str_rocket:fence_" .. key
end

local registered = {}
local function register_fence(sides, interact)
	local name = fence_name(sides)
	if registered[name] then
		return name
	end
	registered[name] = true
	core.register_node(name, {
		description = "Rocket site fence",
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = fence_boxes(sides)},
		tiles = {"str_rocket_fence.png"},
		collision_box = str_rocket.SITE_COLLISION,
		paramtype = "light",
		sunlight_propagates = true,
		pointable = false,
		diggable = false,
		buildable_to = false,
		is_ground_content = false,
		drop = "",
		groups = {not_in_creative_inventory = 1, str_rocket = 1},
		str_interact = interact,
	})
	return name
end

core.register_node(INNER, {
	description = "Rocket site",
	drawtype = "airlike",
	collision_box = str_rocket.SITE_COLLISION,
	paramtype = "light",
	sunlight_propagates = true,
	pointable = false,
	diggable = false,
	buildable_to = false,
	is_ground_content = false,
	drop = "",
	groups = {not_in_creative_inventory = 1, str_rocket = 1},
})

-- Fences of the launch workshop when it ran along Z (test saves only)
core.register_alias("str_rocket:fence_esw", "air")
core.register_alias("str_rocket:fence_new", "air")

-- Node of each footprint cell: a fence on its outer sides, or the empty inside
local cell_nodes = {}
for kind, footprint in pairs(FOOTPRINTS) do
	local inside = {}
	for _, c in ipairs(footprint.cells) do
		inside[c[1] .. "," .. c[2]] = true
	end
	cell_nodes[kind] = {}
	for i, c in ipairs(footprint.cells) do
		local sides, any = {}, false
		for side, d in pairs(SIDE_DIRS) do
			if not inside[(c[1] + d[1]) .. "," .. (c[2] + d[2])] then
				sides[side], any = true, true
			end
		end
		cell_nodes[kind][i] = any and register_fence(sides, kind == "support" and str_rocket.SITE_INTERACT or nil) or INNER
	end
end

local function cells(kind, anchor)
	local out = {}
	for i, c in ipairs(FOOTPRINTS[kind].cells) do
		out[i] = vector.new(anchor.x + c[1], anchor.y, anchor.z + c[2])
	end
	return out
end

local function is_ground(name)
	local def = core.registered_nodes[name]
	return def ~= nil and def.walkable and def.is_ground_content ~= false and (def.liquidtype or "none") == "none"
end

-- Air, or a plant the site may cover
local function is_free(name)
	if name == "air" then
		return true
	end
	local def = core.registered_nodes[name]
	return def ~= nil and def.buildable_to and not def.walkable and (def.liquidtype or "none") == "none"
end

-- Checks the footprint on the pointed ground node; returns the site cells (one above the ground) or nil and why
local function check(kind, ground)
	local list = cells(kind, vector.offset(ground, 0, 1, 0))
	for _, pos in ipairs(list) do
		if pos.z < MIN_Z then
			return nil, "Too close to the slice"
		elseif pos.z > MAX_Z or math.abs(pos.x) > HALF_WIDTH then
			return nil, "Too far out"
		end
	end
	if ground.y < SURFACE_Y then
		return nil, "Must be on the surface"
	end
	for _, pos in ipairs(list) do
		local here, below = core.get_node(pos).name, core.get_node(vector.offset(pos, 0, -1, 0)).name
		if here == "ignore" or below == "ignore" then
			return nil, "Too far out"
		elseif is_ground(here) then
			return nil, "Ground is not level"
		elseif not is_free(here) then
			return nil, "Something is in the way"
		elseif is_free(below) then
			return nil, "Ground is not level"
		elseif not is_ground(below) then
			return nil, "Cannot build on this"
		end
	end
	return list
end

local function blueprint_kind(stack)
	return str_rocket.blueprint_kinds[stack:get_name()]
end

local function surface_ready(player)
	return str_mode.get(player) == "vehicle" and not str_machine.is_dead(player) and str_machine.is_surface(player)
end

-- The client points from the camera rig the player is attached to, along the look
local function pointed_ground(player)
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
	local to = vector.add(eye, vector.multiply(player:get_look_dir(), POINT_RANGE))
	for pointed in core.raycast(eye, to, false, false) do
		if pointed.type == "node" then
			return pointed.under
		end
	end
end

-- Current plan of a player holding a blueprint in surface mode: {kind, ground, cells or nil, why}
local function plan_for(player)
	local kind = blueprint_kind(player:get_wielded_item())
	if not kind or not surface_ready(player) then
		return nil
	end
	local ground = pointed_ground(player)
	if not ground then
		return {kind = kind}
	end
	local list, why = check(kind, ground)
	return {kind = kind, ground = ground, cells = list, why = why}
end

-- Places the fence nodes (or the given node per cell) of a saved site where missing; false if the area is not loaded
function str_rocket.restore(kind, anchor, nodes)
	nodes = nodes or cell_nodes[kind]
	local list = cells(kind, anchor)
	for i, pos in ipairs(list) do
		local name = core.get_node(pos).name
		if name == "ignore" then
			return false
		elseif name ~= nodes[i] then
			core.set_node(pos, {name = nodes[i]})
		end
	end
	return true
end

core.register_entity(PREVIEW, {
	initial_properties = {
		visual = "cube",
		textures = {"str_rocket_preview.png", "str_rocket_preview.png", "str_rocket_preview.png",
			"str_rocket_preview.png", "str_rocket_preview.png", "str_rocket_preview.png"},
		use_texture_alpha = true,
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		glow = 8,
		collisionbox = {0, 0, 0, 0, 0, 0},
		selectionbox = {0, 0, 0, 0, 0, 0},
	},
})

-- player name -> {obj, key, size}
local previews = {}

local function hide(name)
	local preview = previews[name]
	if preview and preview.obj:is_valid() then
		preview.obj:remove()
	end
	previews[name] = nil
end

local function bounds(list)
	local minp, maxp = vector.copy(list[1]), vector.copy(list[1])
	for _, pos in ipairs(list) do
		minp, maxp = vector.new(math.min(minp.x, pos.x), minp.y, math.min(minp.z, pos.z)),
			vector.new(math.max(maxp.x, pos.x), maxp.y, math.max(maxp.z, pos.z))
	end
	return minp, maxp
end

local function show(player, plan, time)
	local name = player:get_player_name()
	local list = cells(plan.kind, vector.offset(plan.ground, 0, 1, 0))
	local minp, maxp = bounds(list)
	local center = vector.divide(vector.add(minp, maxp), 2)
	local size = vector.new(maxp.x - minp.x + 1, 1, maxp.z - minp.z + 1)
	local ok = plan.cells ~= nil
	local key = core.pos_to_string(center) .. tostring(ok)
	local preview = previews[name]
	if not (preview and preview.obj:is_valid()) then
		local obj = core.add_entity(center, PREVIEW)
		if not obj then
			return
		end
		obj:set_observers({[name] = true})
		preview = {obj = obj}
		previews[name] = preview
	end
	if preview.key ~= key then
		preview.key = key
		preview.obj:set_pos(center)
		local tex = "str_rocket_preview.png^[multiply:" .. (ok and GOOD_TINT or BAD_TINT)
		preview.obj:set_properties({textures = {tex, tex, tex, tex, tex, tex}})
	end
	local wobble = 1 + WOBBLE_SIZE * math.sin(time * WOBBLE_SPEED)
	preview.obj:set_properties({visual_size = vector.new(size.x * wobble, size.y * wobble, size.z * wobble)})
end

-- player name -> crosshair hud id
local crosshairs = {}

local function update(player, time)
	local name = player:get_player_name()
	local holding = blueprint_kind(player:get_wielded_item()) and surface_ready(player)
	if holding and not crosshairs[name] then
		crosshairs[name] = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = 1, y = 1}, z_index = 10, text = CROSSHAIR,
		})
	elseif not holding and crosshairs[name] then
		player:hud_remove(crosshairs[name])
		crosshairs[name] = nil
	end
	local plan = holding and plan_for(player)
	if plan and plan.ground then
		show(player, plan, time)
	else
		hide(name)
	end
end

local elapsed, clock = 0, 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	clock = clock + dtime
	if elapsed < INTERVAL then
		return
	end
	elapsed = 0
	for _, player in ipairs(core.get_connected_players()) do
		update(player, clock)
	end
end)

-- player name -> plan waiting for the confirm window
local pending = {}

local function confirm_form(plan)
	local title = FOOTPRINTS[plan.kind].title
	local w, y = 8, str_gui.CONTENT_Y
	return table.concat({
		str_gui.header(w, y + 2.6, "Place " .. title),
		("textarea[0.4,%g;7.2,1.2;;;%s]"):format(y, core.formspec_escape(
			("Place the %s here?\nPlacement is permanent, choose carefully."):format(title))),
		("button[0.4,%g;3.5,0.8;place;Place]"):format(y + 1.4),
		("button_exit[4.1,%g;3.5,0.8;cancel;Cancel]"):format(y + 1.4),
	})
end

local function take_blueprint(player, kind)
	local item = str_rocket.blueprint_items[kind]
	local inv = player:get_inventory()
	for listname in pairs(inv:get_lists()) do
		if inv:contains_item(listname, item) then
			inv:remove_item(listname, item)
			return true
		end
	end
	return false
end

local function place(player, plan)
	local name = player:get_player_name()
	local d = str_rocket.data(name)
	if d[plan.kind] then
		return "You already placed one"
	end
	local list, why = check(plan.kind, plan.ground)
	if not list then
		return why
	end
	if not take_blueprint(player, plan.kind) then
		return "The blueprint is gone"
	end
	d[plan.kind] = vector.offset(plan.ground, 0, 1, 0)
	str_rocket.save(name)
	str_rocket.restore(plan.kind, d[plan.kind])
	hide(name)
end

function str_rocket.use_blueprint(itemstack, user)
	local name = user:get_player_name()
	if not surface_ready(user) then
		str_utils.show_popup(name, "Use in surface mode: hold Space above ground", 3, true)
		return
	end
	local plan = plan_for(user)
	if not plan or not plan.ground then
		str_utils.show_popup(name, "Point at the ground", 2, true)
		return
	elseif not plan.cells then
		str_utils.show_popup(name, plan.why, 2, true)
		return
	end
	pending[name] = plan
	core.show_formspec(name, FORM, confirm_form(plan))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then
		return
	end
	local name = player:get_player_name()
	local plan = pending[name]
	if fields.place and plan then
		pending[name] = nil
		core.close_formspec(name, FORM)
		local err = place(player, plan)
		if err then
			str_utils.show_popup(name, err, 2, true)
		end
	elseif fields.quit then
		pending[name] = nil
	end
	return true
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	hide(name)
	crosshairs[name] = nil
	pending[name] = nil
end)
