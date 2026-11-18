local crates = str_cargo_crates

local NODE = "str_cargo_crates:crate"
local KEY_PREFIX = "crates:"
local LIMITS = str_utils.constants.cargo_crate

local storage = core.get_mod_storage()

-- owner -> list of crate records {pos, private, items = {name = count}}
local by_owner = {}
-- node position hash -> {owner, record}
local by_pos = {}
local listeners = {}

crates.NODE = NODE

core.register_node(NODE, {
	description = "Cargo crate",
	drawtype = "nodebox",
	-- The warehouse crate's shape, made shallow so it sits against the back wall behind the machine
	node_box = {type = "fixed", fixed = {
		{-13/32, -16/32, 0, 13/32, 14/32, 14/32},
		{-14/32, 14/32, -1/32, 14/32, 16/32, 15/32},
		{-14/32, -16/32, -1/32, -11/32, 14/32, 2/32},
		{11/32, -16/32, -1/32, 14/32, 14/32, 2/32},
		{-14/32, -16/32, 12/32, -11/32, 14/32, 15/32},
		{11/32, -16/32, 12/32, 14/32, 14/32, 15/32},
	}},
	tiles = {
		"str_interior_shop_crate_large_top.png", "str_interior_shop_crate_large_bottom.png",
		"str_interior_shop_crate_large_right.png", "str_interior_shop_crate_large_left.png",
		"str_interior_shop_crate_large_back.png", "str_interior_shop_crate_large_front.png",
	},
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = false,
	floodable = false,
	is_ground_content = false,
	drop = "",
	groups = str_utils.get_common_groups({not_in_creative_inventory = 1, [str_groups.CARGO_CRATE] = 1}),
	str_interact = "cargo_crate",
})

local function save(owner)
	local list = by_owner[owner]
	if not list or #list == 0 then
		by_owner[owner] = nil
		storage:set_string(KEY_PREFIX .. owner, "")
		return
	end
	local out = {}
	for i, rec in ipairs(list) do
		out[i] = {pos = {x = rec.pos.x, y = rec.pos.y, z = rec.pos.z}, private = rec.private, items = rec.items}
	end
	storage:set_string(KEY_PREFIX .. owner, core.write_json(out))
end

local function changed(pos, owner)
	for _, fn in ipairs(listeners) do
		fn(pos, owner)
	end
end

for _, key in ipairs(storage:get_keys()) do
	local owner = key:sub(1, #KEY_PREFIX) == KEY_PREFIX and key:sub(#KEY_PREFIX + 1)
	local raw = owner and storage:get_string(key)
	local data = raw and raw ~= "" and core.parse_json(raw)
	if type(data) == "table" then
		local list = {}
		for _, rec in ipairs(data) do
			local p = type(rec) == "table" and rec.pos
			if type(p) == "table" and tonumber(p.x) and tonumber(p.y) and tonumber(p.z) and type(rec.items) == "table" then
				local pos = vector.round(vector.new(tonumber(p.x), tonumber(p.y), tonumber(p.z)))
				local hash = core.hash_node_position(pos)
				if not by_pos[hash] and next(rec.items) then
					local entry = {pos = pos, private = rec.private ~= false, items = rec.items}
					list[#list + 1] = entry
					by_pos[hash] = {owner = owner, record = entry}
				end
			end
		end
		by_owner[owner] = list
	end
end

local function lookup(pos)
	return by_pos[core.hash_node_position(vector.round(pos))]
end

local function put_node(pos)
	if core.get_node(pos).name ~= NODE then
		core.set_node(pos, {name = NODE})
		str_nodes.refresh_shapes(pos)
	end
end

local function delete(found)
	local list = by_owner[found.owner] or {}
	for i, rec in ipairs(list) do
		if rec == found.record then
			table.remove(list, i)
			break
		end
	end
	local pos = found.record.pos
	by_pos[core.hash_node_position(pos)] = nil
	save(found.owner)
	if core.get_node(pos).name == NODE then
		core.remove_node(pos)
		str_nodes.refresh_shapes(pos)
	end
end

-- fn(pos, owner) runs after the crate at pos changes (contents, privacy, or removed)
function crates.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

-- Name of the player who owns the crate at pos, or nil if there is none
function crates.owner(pos)
	local found = lookup(pos)
	return found and found.owner
end

function crates.is_private(pos)
	local found = lookup(pos)
	return found ~= nil and found.record.private
end

function crates.set_private(pos, private)
	local found = lookup(pos)
	if found then
		found.record.private = private and true or false
		save(found.owner)
		changed(found.record.pos, found.owner)
	end
end

-- Whether player_name may take from and store into the crate at pos
function crates.can_use(player_name, pos)
	local found = lookup(pos)
	return found ~= nil and (found.owner == player_name or not found.record.private)
end

-- Number of crates owner has across all slices
function crates.count(owner)
	return #(by_owner[owner] or {})
end

-- Copies of owner's crates {pos, private, items}, in the order they were made
function crates.list(owner)
	local out = {}
	for i, rec in ipairs(by_owner[owner] or {}) do
		out[i] = {pos = vector.copy(rec.pos), private = rec.private, items = table.copy(rec.items)}
	end
	return out
end

function crates.get(pos)
	local found = lookup(pos)
	return found and table.copy(found.record.items) or {}
end

function crates.volume(pos)
	local sum = 0
	for name, count in pairs(crates.get(pos)) do
		local def = str_materials.get(name)
		if def then
			sum = sum + def.volume * count
		end
	end
	return sum
end

function crates.free_volume(pos)
	return lookup(pos) and math.max(LIMITS.capacity - crates.volume(pos), 0) or 0
end

-- Adds as many units as fit into the crate at pos; returns how many were added
function crates.add(pos, name, count)
	local found = lookup(pos)
	local def = str_materials.get(name)
	if not found or not def then
		return 0
	end
	local fit = math.min(count, math.floor(crates.free_volume(pos) / def.volume + 1e-6))
	if fit <= 0 then
		return 0
	end
	local items = found.record.items
	items[name] = (items[name] or 0) + fit
	save(found.owner)
	changed(found.record.pos, found.owner)
	return fit
end

-- Removes up to count units; returns how many were removed. An emptied crate vanishes
function crates.remove(pos, name, count)
	local found = lookup(pos)
	local items = found and found.record.items
	local removed = items and math.min(count, items[name] or 0) or 0
	if removed <= 0 then
		return 0
	end
	items[name] = items[name] - removed
	if items[name] == 0 then
		items[name] = nil
	end
	if next(items) then
		save(found.owner)
	else
		delete(found)
	end
	changed(found.record.pos, found.owner)
	return removed
end

-- Removes the crate at pos with everything in it; returns what it held
function crates.destroy(pos)
	local found = lookup(pos)
	if not found then
		return {}
	end
	local items = found.record.items
	delete(found)
	changed(found.record.pos, found.owner)
	return items
end

-- Why a new crate can't go in the cell at pos, or nil if it can
local function placement_problem(pos)
	if core.get_node(pos).name ~= "air" and not str_piles.get(pos) then
		return "No room for a crate here."
	end
	local below = core.get_node(vector.offset(pos, 0, -1, 0)).name
	local def = core.registered_nodes[below]
	if not def or def.walkable == false then
		return "Crates must be dropped on solid ground."
	end
	if below:find("^str_pads:") then
		return "Crates can't be dropped on a pad."
	end
	local behind = core.get_node(vector.offset(pos, 0, 0, 1)).name
	def = core.registered_nodes[behind]
	if def and (def.str_interact or behind:find("^str_buildings:")) then
		return "Crates can't be dropped in front of that."
	end
end

-- Moves up to count units of name from the hold into a crate in the machine's cell, making one if
-- needed (taking in any ore pile there first). Returns how many moved and, when none did, the reason.
function crates.drop(player, name, count)
	local machine_pos = str_mode.get(player) == "vehicle" and str_machine.get_pos(player)
	if not machine_pos then
		return 0, "Only the machine can drop crates."
	end
	local cargo = str_machine.cargo
	count = math.min(count, cargo.get(player)[name] or 0)
	if count <= 0 then
		return 0, "Nothing to drop."
	end
	local pos = vector.round(machine_pos)
	local owner = player:get_player_name()
	local made = false
	if lookup(pos) then
		if not crates.can_use(owner, pos) then
			return 0, "Someone else's crate is here."
		end
	else
		local problem = placement_problem(pos)
		if problem then
			return 0, problem
		end
		if crates.count(owner) >= LIMITS.per_player then
			return 0, ("Crate limit reached (%d)."):format(LIMITS.per_player)
		end
		local record = {pos = pos, private = true, items = {}}
		by_owner[owner] = by_owner[owner] or {}
		table.insert(by_owner[owner], record)
		by_pos[core.hash_node_position(pos)] = {owner = owner, record = record}
		made = true
		local pile_item, pile_count = str_piles.get(pos)
		if pile_item then
			crates.add(pos, pile_item, pile_count)
		end
	end
	local added = crates.add(pos, name, count)
	if added > 0 then
		cargo.remove(player, name, added)
	end
	if made then
		local found = lookup(pos)
		if next(found.record.items) then
			put_node(pos)
		else
			delete(found)
		end
	end
	if added <= 0 then
		return 0, "The crate is full. Move to another spot."
	end
	return added
end

str_inventory.set_drop_handler(crates.drop)

-- Puts back every crate inside minp..maxp (the ground there was just generated or regenerated)
local function restore(minp, maxp)
	for _, found in pairs(by_pos) do
		local pos = found.record.pos
		if vector.in_area(pos, minp, maxp) then
			put_node(pos)
		end
	end
end

str_worldgen.register_on_regenerate(restore)

core.register_on_generated(function(minp, maxp)
	restore(minp, maxp)
end)

-- Each slice mapblock has a liquid stop; on load, crates whose node went missing are put back
core.register_lbm({
	name = "str_cargo_crates:restore",
	label = "Put back cargo crates missing from their cell",
	nodenames = {"str_nodes:liquid_stop"},
	run_at_every_load = true,
	bulk_action = function(pos_list)
		local bp = vector.floor(vector.divide(pos_list[1], core.MAP_BLOCKSIZE))
		local minp = vector.multiply(bp, core.MAP_BLOCKSIZE)
		restore(vector.new(minp.x, minp.y, minp.z), vector.add(minp, core.MAP_BLOCKSIZE - 1))
	end,
})

-- Crate nodes whose record is gone (e.g. emptied while the block was unloaded) are cleared
core.register_lbm({
	name = "str_cargo_crates:orphans",
	label = "Remove cargo crates that have no stored contents",
	nodenames = {NODE},
	run_at_every_load = true,
	action = function(pos)
		if not lookup(pos) then
			core.remove_node(pos)
			str_nodes.refresh_shapes(pos)
		end
	end,
})
