-- Decoration the player places in their own workshop from the hand hotbar. A piece is one or more cell nodes
-- laid out to the player's right; each variant stands on its own support group (floor, counter). Only the anchor
-- cell (offset 0,0,0) is saved by str_interior_storage; restoring it rebuilds the whole piece.
local storage = core.get_mod_storage()

str_furnish.pieces = {}
str_furnish.list = {}
str_furnish.by_item = {}
-- Pointing with a piece item reaches the interior's blocking nodes (floors, counters)
str_furnish.POINTABILITIES = {nodes = {["group:" .. str_groups.BLOCKING] = true}}
local BAD_TINT = "^[multiply:#ff4a3a"
local GOOD_TINT = "^[multiply:#b4ffaa"
local FACES = {"top", "bottom", "left", "right", "back", "front"}

for _, material in ipairs({"metal", "wood"}) do
	str_audio.sfx.register("furnish_place_" .. material, {sound = "str_interior_footstep_" .. material, gain = 0.4})
	str_audio.sfx.register("furnish_pick_up_" .. material, {sound = "str_interior_footstep_" .. material, gain = 0.8})
end

-- Offset in piece space (+X is the player's right) turned like a 4dir node
local ROTATE = {
	[0] = function(o) return vector.new(o.x, o.y, o.z) end,
	function(o) return vector.new(o.z, o.y, -o.x) end,
	function(o) return vector.new(-o.x, o.y, -o.z) end,
	function(o) return vector.new(-o.z, o.y, o.x) end,
}

function str_furnish.rotate(offset, param2)
	return ROTATE[param2 % 4](offset)
end

local function node_def(pos)
	return core.registered_nodes[core.get_node(pos).name]
end

local function is_free(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return node.name ~= "ignore" and def ~= nil and def.buildable_to == true
end

local function cell_positions(anchor, variant, param2)
	local list = {}
	for i, cell in ipairs(variant.cells) do
		list[i] = vector.add(anchor, str_furnish.rotate(cell.offset, param2))
	end
	return list
end

-- Free cells, each standing on the variant's support
local function fits(anchor, variant, param2)
	for _, pos in ipairs(cell_positions(anchor, variant, param2)) do
		if not is_free(pos) or not str_groups.at(vector.offset(pos, 0, -1, 0), variant.support) then
			return false
		end
	end
	return true
end

-- Whether a player's collision box reaches into the node at pos
local function player_in(pos)
	for obj in core.objects_inside_radius(pos, 2.5) do
		if obj:is_player() then
			local p, box = obj:get_pos(), obj:get_properties().collisionbox
			if p.x + box[1] < pos.x + 0.5 and p.x + box[4] > pos.x - 0.5
					and p.y + box[2] < pos.y + 0.5 and p.y + box[5] > pos.y - 0.5
					and p.z + box[3] < pos.z + 0.5 and p.z + box[6] > pos.z - 0.5 then
				return true
			end
		end
	end
	return false
end

-- Where the piece would go for this pointed thing: {variant, anchor, param2, cells = {pos, ...}, ok}, nil if no node
function str_furnish.plan(player, piece, pointed)
	if not pointed or pointed.type ~= "node" then
		return nil
	end
	local anchor = node_def(pointed.under) and node_def(pointed.under).buildable_to and pointed.under or pointed.above
	local below = vector.offset(anchor, 0, -1, 0)
	local variant = piece.variants[1]
	for _, candidate in ipairs(piece.variants) do
		if str_groups.at(below, candidate.support) then
			variant = candidate
			break
		end
	end
	local yaw = player:get_look_horizontal()
	if player:get_player_control().sneak then
		yaw = yaw + math.pi
	end
	local param2 = core.dir_to_fourdir(core.yaw_to_dir(yaw))
	local name = player:get_player_name()
	local cells = cell_positions(anchor, variant, param2)
	local ok = fits(anchor, variant, param2)
	for _, pos in ipairs(cells) do
		if not ok then
			break
		end
		ok = str_start.owner_at(pos) == name and not core.is_protected(pos, name) and not player_in(pos)
	end
	return {variant = variant, anchor = anchor, param2 = param2, cells = cells, ok = ok}
end

local function set_cells(anchor, variant, param2)
	for i, pos in ipairs(cell_positions(anchor, variant, param2)) do
		core.set_node(pos, {name = variant.cells[i].name, param2 = param2})
	end
end

local function place(itemstack, placer, pointed)
	local piece = placer and placer:is_player() and str_furnish.by_item[itemstack:get_name()]
	if not piece or str_mode.get(placer) ~= "foot" then
		return itemstack
	end
	local plan = str_furnish.plan(placer, piece, pointed)
	if not plan then
		return itemstack
	end
	if not plan.ok then
		str_utils.show_popup(placer:get_player_name(), "No room here.", 2, true)
		return itemstack
	end
	set_cells(plan.anchor, plan.variant, plan.param2)
	str_interior.notify_state_change(plan.anchor, core.get_node(plan.anchor))
	str_audio.sfx.play("furnish_place_" .. piece.material, {pos = plan.anchor})
	itemstack:take_item()
	return itemstack
end

-- Items that did not fit anywhere wait in mod storage until the player has room
local function pending_key(player_name)
	return "returned:" .. player_name
end

local function load_pending(player_name)
	local raw = storage:get_string(pending_key(player_name))
	local list = raw ~= "" and core.parse_json(raw) or nil
	return type(list) == "table" and list or {}
end

local function store_pending(player_name, list)
	storage:set_string(pending_key(player_name), #list > 0 and core.write_json(list) or "")
end

local function give_back(player_name, item)
	local player = core.get_player_by_name(player_name)
	local left = player and str_hotbar.give(player, item) or ItemStack(item)
	if not left:is_empty() then
		local list = load_pending(player_name)
		list[#list + 1] = left:to_string()
		store_pending(player_name, list)
	end
end

local function flush_pending(player)
	local name = player:get_player_name()
	local list, kept = load_pending(name), {}
	if #list == 0 then
		return
	end
	for _, item in ipairs(list) do
		local left = str_hotbar.give(player, item)
		if not left:is_empty() then
			kept[#kept + 1] = left:to_string()
		end
	end
	store_pending(name, kept)
end

core.register_on_joinplayer(flush_pending)
str_mode.register_on_change(flush_pending)

-- The placed piece whose cell is at pos, if player (on foot) owns it: piece, variant, anchor, param2
function str_furnish.owned_piece(pos, player)
	if not (player and player:is_player()) or str_mode.get(player) ~= "foot" then
		return nil
	end
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	local piece, variant = def and str_furnish.pieces[def._str_piece], nil
	for _, candidate in ipairs(piece and piece.variants or {}) do
		if candidate.id == def._str_variant then
			variant = candidate
		end
	end
	if not variant then
		return nil
	end
	local anchor = vector.subtract(pos, str_furnish.rotate(def._str_offset, node.param2))
	if str_start.owner_at(anchor) ~= player:get_player_name() then
		return nil
	end
	return piece, variant, anchor, node.param2
end

-- Removes the piece with a cell at pos and gives its item back; returns whether it was picked up
function str_furnish.pick_up(pos, player)
	local piece, variant, anchor, param2 = str_furnish.owned_piece(pos, player)
	if not piece then
		return false
	end
	local name = player:get_player_name()
	if not str_hotbar.room_for(player, piece.item) then
		str_utils.show_popup(name, "Your hand hotbar is full.", 2, true)
		return false
	end
	for i, cell_pos in ipairs(cell_positions(anchor, variant, param2)) do
		if core.get_node(cell_pos).name == variant.cells[i].name then
			core.remove_node(cell_pos)
		end
	end
	str_interior.notify_state_change(anchor, {name = "air"})
	str_hotbar.give(player, piece.item)
	str_audio.sfx.play("furnish_pick_up_" .. piece.material, {pos = anchor})
	return true
end

local PICK_UP_W, PICK_UP_H = 2, 0.7

-- The Pick up button (field pick_up) in the top right of a window's header bar
function str_furnish.pick_up_button(window_w)
	return ("button[%g,%g;%g,%g;pick_up;Pick up]"):format(window_w - PICK_UP_W - 0.15,
		(str_gui.theme.header_height - PICK_UP_H) / 2, PICK_UP_W, PICK_UP_H)
end

local function show_window(pos, _, clicker)
	local piece = str_furnish.owned_piece(pos, clicker)
	if piece and piece.window then
		piece.window(clicker, pos)
	end
end

local function use_piece(pos, node, clicker)
	local piece = str_furnish.owned_piece(pos, clicker)
	if piece and piece.use then
		piece.use(clicker, pos, node)
	end
end

-- Sneak + punch picks a piece up; pieces with a window of their own are right-clicked instead
local function punch_pick_up(pos, _, puncher)
	if puncher and puncher:is_player() and puncher:get_player_control().sneak then
		str_furnish.pick_up(pos, puncher)
	end
end

local function tiles(node, tint)
	local list = {}
	for i, face in ipairs(FACES) do
		list[i] = "str_furnish_" .. node .. "_" .. face .. ".png" .. (tint or "")
	end
	return list
end

local function fixed(boxes)
	return boxes and {type = "fixed", fixed = boxes}
end

-- def: {description, info, material ("metal" or "wood": footstep, place and pick-up sounds), from = {material = amount}, image, item (default "str_furnish:<name>"),
-- prompt (default description), station (made there instead of Create Items, so no blueprint),
-- use (fn(player, pos, node) on right-click for a piece without a window),
-- window (fn(player, pos) shown on right-click; such a piece is picked up from its window, others by sneak + punch), variants = {{id, support = group,
-- cells = {{node, offset, boxes, selection, collision, pointable}, ...}}, ...}}.
-- The first cell of each variant must be at offset 0,0,0. Cell textures: str_furnish_<node>_<face>.png
function str_furnish.register_piece(name, def)
	assert(def.material == "metal" or def.material == "wood", "str_furnish: piece needs material metal or wood")
	local piece = {
		name = name, material = def.material, description = def.description, info = def.info, from = def.from,
		item = def.item or "str_furnish:" .. name, variants = def.variants, station = def.station,
		window = def.window, use = def.use,
	}
	str_furnish.pieces[name] = piece
	str_furnish.list[#str_furnish.list + 1] = piece
	str_furnish.by_item[piece.item] = piece
	if not def.station then
		piece.recipe = str_recipes.add_item_recipe({name = name, description = def.description, from = def.from})
	end

	for _, variant in ipairs(def.variants) do
		assert(vector.equals(variant.cells[1].offset, vector.zero()), "str_furnish: anchor cell must be at 0,0,0")
		for i, cell in ipairs(variant.cells) do
			cell.name = "str_furnish:" .. cell.node
			cell.bad = cell.name .. "_bad"
			cell.good = cell.name .. "_good"
			local node = {
				description = def.description,
				drawtype = "nodebox",
				paramtype = "light",
				paramtype2 = "4dir",
				tiles = tiles(cell.node),
				node_box = fixed(cell.boxes),
				selection_box = fixed(cell.selection),
				collision_box = fixed(cell.collision),
				pointable = cell.pointable,
				groups = {not_in_creative_inventory = 1},
				is_ground_content = false,
				sunlight_propagates = true,
				drop = "",
				sounds = {footstep = {name = "str_interior_footstep_" .. def.material, gain = 1.0}},
				_str_piece = name,
				_str_variant = variant.id,
				_str_offset = cell.offset,
				_str_prompt = def.prompt or def.description,
				on_rightclick = piece.window and show_window or piece.use and use_piece or nil,
				on_punch = not piece.window and punch_pick_up or nil,
			}
			if i == 1 then
				node._str_placed = true
				node._str_state_dirty = true
				node._str_restore = function(pos, saved)
					if not fits(pos, variant, saved.param2) then
						return false
					end
					set_cells(pos, variant, saved.param2)
					return true
				end
				node._str_on_state_dropped = function(player_name)
					give_back(player_name, piece.item)
				end
			end
			core.register_node(cell.name, node)
			for preview_name, tint in pairs({[cell.bad] = BAD_TINT, [cell.good] = GOOD_TINT}) do
				core.register_node(preview_name, {
					description = def.description .. " (preview)",
					drawtype = "nodebox",
					paramtype = "light",
					paramtype2 = "4dir",
					tiles = tiles(cell.node, tint),
					node_box = fixed(cell.boxes),
					groups = {not_in_creative_inventory = 1},
					pointable = false,
					walkable = false,
					drop = "",
				})
			end
		end
	end

	assert(not core.registered_nodes[piece.item], "str_furnish: item name " .. piece.item .. " is also a node")
	core.register_craftitem(piece.item, {
		description = def.description .. "\n" .. def.info,
		short_description = def.description,
		inventory_image = def.image,
		groups = {[str_groups.FOOT_ITEM] = 1},
		pointabilities = str_furnish.POINTABILITIES,
		stack_max = 10,
		on_place = place,
		on_drop = function(itemstack) return itemstack end,
	})
end
