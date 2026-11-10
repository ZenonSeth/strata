-- Two-node door: a bottom half you click and a top half that is only visuals and collision.
-- The bottom half's selection box reaches up over the top half, so it shows as one box.
-- Closed the leaf lies along the -Z face (before rotation), open it is swung onto the -X edge.
-- Textures and shapes from tools/gen_door.py

local register_node = st_interior.register_node

st_audio.sfx.register("door_open", {sound = "st_interior_door_open", max_hear_distance = 16})
st_audio.sfx.register("door_close", {sound = "st_interior_door_close", max_hear_distance = 16})

local LEAF = 2 / 32  -- leaf thickness, also the selection depth

local function nodebox_closed()
	return {type = "fixed", fixed = {-16/32, -16/32, -16/32, 16/32, 16/32, -16/32 + LEAF}}
end

local function nodebox_open()
	return {type = "fixed", fixed = {-16/32, -16/32, -16/32, -16/32 + LEAF, 16/32, 16/32}}
end

local function tiles(name)
	local t = {}
	for i, face in ipairs({"top", "bottom", "left", "right", "back", "front"}) do
		t[i] = "st_interior_" .. name .. "_" .. face .. ".png"
	end
	return t
end

local function is_free(pos, player_name)
	local def = core.registered_nodes[core.get_node(pos).name]
	return def and def.buildable_to and not core.is_protected(pos, player_name)
end

local function register_door(skin, description)
	local base = "door_" .. skin
	local names = {
		bottom = base, bottom_open = base .. "_open",
		top = base .. "_top", top_open = base .. "_top_open",
	}
	local full = {}
	for key, name in pairs(names) do
		full["st_interior:" .. name] = key
	end

	local function partner_toggle(key)
		return key:find("_open$") and key:gsub("_open$", "") or key .. "_open"
	end

	local function toggle(pos, node, clicker)
		local player = clicker and clicker:get_player_name() or ""
		if core.is_protected(pos, player) then
			return
		end
		local key = full[node.name]
		local top_pos = vector.offset(pos, 0, 1, 0)
		local top = core.get_node(top_pos)
		local top_key = full[top.name]
		if top_key ~= key:gsub("bottom", "top") then
			return
		end
		core.swap_node(pos, {name = "st_interior:" .. names[partner_toggle(key)], param2 = node.param2})
		st_audio.sfx.play(key:find("_open$") and "door_close" or "door_open", {pos = top_pos})
		core.swap_node(top_pos, {name = "st_interior:" .. names[partner_toggle(top_key)], param2 = top.param2})
	end

	for _, half in ipairs({"bottom", "top"}) do
		for _, state in ipairs({"closed", "open"}) do
			local open = state == "open"
			local key = half .. (open and "_open" or "")
			local name = names[key]
			local box = open and nodebox_open() or nodebox_closed()
			local def = {
				description = description .. (half == "top" and " (top half)" or ""),
				drawtype = "nodebox",
				paramtype = "light",
				paramtype2 = "4dir",
				tiles = tiles("door_" .. skin .. (half == "top" and "_top" or "_bottom") .. (open and "_open" or "")),
				node_box = box,
				collision_box = box,
			}
			if half == "bottom" then
				local pick = open and {-16/32, -16/32, -16/32, -16/32 + LEAF, 48/32, 16/32}
					or {-16/32, -16/32, -16/32, 16/32, 48/32, -16/32 + LEAF}
				def.selection_box = {type = "fixed", fixed = pick}
				def.on_rightclick = function(pos, node, clicker)
					toggle(pos, node, clicker)
				end
				def.on_destruct = function(pos)
					local top_pos = vector.offset(pos, 0, 1, 0)
					if full[core.get_node(top_pos).name] then
						core.remove_node(top_pos)
					end
				end
				def.drop = "st_interior:" .. names.bottom
				if not open then
					def.on_place = function(itemstack, placer, pointed_thing)
						if pointed_thing.type ~= "node" then
							return itemstack
						end
						local under = core.get_node(pointed_thing.under)
						local under_def = core.registered_nodes[under.name]
						local sneaking = placer and placer:get_player_control().sneak
						if not (under_def and under_def.on_rightclick) or sneaking then
							local pos = (under_def and under_def.buildable_to) and pointed_thing.under
								or pointed_thing.above
							local player = placer and placer:get_player_name() or ""
							if not is_free(vector.offset(pos, 0, 1, 0), player) then
								return itemstack
							end
						end
						return core.item_place(itemstack, placer, pointed_thing)
					end
					def.after_place_node = function(pos)
						core.set_node(vector.offset(pos, 0, 1, 0),
							{name = "st_interior:" .. names.top, param2 = core.get_node(pos).param2})
					end
				else
					def.groups = {not_in_creative_inventory = 1}
				end
			else
				-- the top half is never pointed at; the bottom half's box covers it
				def.pointable = false
				def.drop = ""
				def.groups = {not_in_creative_inventory = 1}
			end
			register_node(name, def)
		end
	end
end

register_door("wood", "Wooden door")
