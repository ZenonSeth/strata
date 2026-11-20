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
local FACES = {"top", "bottom", "left", "right", "back", "front"}

str_audio.sfx.register("furnish_place", {sound = "str_upgrades_bolt", gain = 0.4})
str_audio.sfx.register("furnish_pick_up", {sound = "str_interior_footstep_metal", gain = 0.8})

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
	local param2 = core.dir_to_fourdir(core.yaw_to_dir(player:get_look_horizontal()))
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
	str_audio.sfx.play("furnish_place", {pos = plan.anchor})
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

local function pick_up(pos, node, puncher)
	if not (puncher and puncher:is_player()) or str_mode.get(puncher) ~= "foot" then
		return
	end
	local def = core.registered_nodes[node.name]
	local piece, variant = def and str_furnish.pieces[def._str_piece], nil
	for _, candidate in ipairs(piece and piece.variants or {}) do
		if candidate.id == def._str_variant then
			variant = candidate
		end
	end
	local name = puncher:get_player_name()
	local anchor = vector.subtract(pos, str_furnish.rotate(def._str_offset, node.param2))
	if not variant or str_start.owner_at(anchor) ~= name then
		return
	end
	if not str_hotbar.room_for(puncher, piece.item) then
		str_utils.show_popup(name, "Your hand hotbar is full.", 2, true)
		return
	end
	for i, cell_pos in ipairs(cell_positions(anchor, variant, node.param2)) do
		if core.get_node(cell_pos).name == variant.cells[i].name then
			core.remove_node(cell_pos)
		end
	end
	str_interior.notify_state_change(anchor, {name = "air"})
	str_hotbar.give(puncher, piece.item)
	str_audio.sfx.play("furnish_pick_up", {pos = anchor})
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

-- def: {description, info, from = {material = amount}, image, item (default "str_furnish:<name>"),
-- variants = {{id, support = group, cells = {{node, offset, boxes, selection, collision}, ...}}, ...}}.
-- The first cell of each variant must be at offset 0,0,0. Cell textures: str_furnish_<node>_<face>.png
function str_furnish.register_piece(name, def)
	local piece = {
		name = name, description = def.description, info = def.info, from = def.from,
		item = def.item or "str_furnish:" .. name, variants = def.variants,
	}
	str_furnish.pieces[name] = piece
	str_furnish.list[#str_furnish.list + 1] = piece
	str_furnish.by_item[piece.item] = piece
	piece.recipe = str_recipes.add_item_recipe({name = name, description = def.description, from = def.from})

	for _, variant in ipairs(def.variants) do
		assert(vector.equals(variant.cells[1].offset, vector.zero()), "str_furnish: anchor cell must be at 0,0,0")
		for i, cell in ipairs(variant.cells) do
			cell.name = "str_furnish:" .. cell.node
			cell.bad = cell.name .. "_bad"
			local node = {
				description = def.description,
				drawtype = "nodebox",
				paramtype = "light",
				paramtype2 = "4dir",
				tiles = tiles(cell.node),
				node_box = fixed(cell.boxes),
				selection_box = fixed(cell.selection),
				collision_box = fixed(cell.collision),
				groups = {not_in_creative_inventory = 1},
				is_ground_content = false,
				sunlight_propagates = true,
				drop = "",
				sounds = {footstep = {name = "str_interior_footstep_metal", gain = 1.0}},
				_str_piece = name,
				_str_variant = variant.id,
				_str_offset = cell.offset,
				on_punch = pick_up,
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
			core.register_node(cell.bad, {
				description = def.description .. " (preview)",
				drawtype = "nodebox",
				paramtype = "light",
				paramtype2 = "4dir",
				tiles = tiles(cell.node, BAD_TINT),
				node_box = fixed(cell.boxes),
				groups = {not_in_creative_inventory = 1},
				pointable = false,
				walkable = false,
				drop = "",
			})
		end
	end

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
