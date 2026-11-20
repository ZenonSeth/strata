local ITEM = "str_scanner:scanner"
-- Same reach as the lasers, so any node on screen can be scanned
local POINT_RANGE = 24
local INTERVAL = 0.1
local HUD = "str_scanner:readout"
local LIQUID_COLLECTION = "str_machine:hull_liquid_collection"
local LAVA_PROTECTION = "str_machine:hull_lava_protection"
local CROSSHAIR = "str_lasers_crosshair.png^[multiply:#a8ecff"
local MINERAL, MUTED, GOOD, BAD = "#e8c46a", "#a0a0a0", "#55dd55", "#ff4500"

str_scanner.ITEM = ITEM

core.register_craftitem(ITEM, {
	description = "Scanner\nPoint at a node in your slice to see its rock, mineral and tier",
	short_description = "Scanner",
	inventory_image = "str_scanner_scanner.png",
	stack_max = 1,
	range = POINT_RANGE,
	on_drop = function(itemstack) return itemstack end,
})

str_hud.register_text(HUD, {
	position = {x = 0.5, y = 0}, offset = {x = 0, y = 100}, size = 1.3, color = 0xFFFFFF,
	mode = "vehicle", background = {},
})

-- node name -> {name, material, richness, tier, liquid}, or false for nodes the scanner ignores
local infos = {}

function str_scanner.describe(node_name)
	if infos[node_name] == nil then
		local def, info = core.registered_nodes[node_name], false
		if def and def.liquidtype ~= "none" then
			info = def.str_material and {name = "Liquid", material = def.str_material, liquid = def.liquidtype} or false
		elseif def and def.str_tier then
			local host = def.str_host and core.registered_nodes[def.str_host]
			info = {name = (host or def).description, material = def.str_material,
				richness = def.str_richness, tier = def.str_tier, hot = def.str_hot}
		end
		infos[node_name] = info
	end
	return infos[node_name] or nil
end

local function mineral_line(player, info)
	local def = info.material and str_materials.get(info.material)
	if not def then
		return nil
	elseif def.kind == "relic" or not str_recipes.has_found(player, info.material) then
		return core.colorize(MUTED, "???")
	end
	local label = info.richness and ("%s (%s)"):format(def.description, info.richness) or def.description
	return core.colorize(MINERAL, label)
end

local function status_line(player, info)
	if info.liquid == "flowing" then
		return core.colorize(MUTED, "Flowing, cannot be collected")
	elseif info.liquid then
		if str_machine.hull_slots.has(player, LIQUID_COLLECTION) then
			return core.colorize(GOOD, "Drive into it to collect it")
		end
		return core.colorize(BAD, "Needs Liquid collection to collect")
	end
	local drill = str_machine.stats.get(player).drill_tier
	if info.tier <= drill then
		return core.colorize(GOOD, ("Tier %d - your drill can dig it"):format(info.tier))
	end
	return core.colorize(BAD, ("Tier %d - too hard for your tier %d drill"):format(info.tier, drill))
end

-- The client points from the camera rig the player is attached to, along the look
local function pointed_cell(player)
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
	local to = vector.add(eye, vector.multiply(player:get_look_dir(), POINT_RANGE))
	for pointed in core.raycast(eye, to, false, false) do
		if pointed.type == "node" then
			return pointed.under
		end
	end
end

local function readout(player, machine_pos)
	local cell = pointed_cell(player)
	-- Only the machine's own slice; the backing wall behind it cannot be dug
	if not cell or cell.z ~= math.floor(machine_pos.z + 0.5) then
		return ""
	end
	local info = str_scanner.describe(core.get_node(cell).name)
	if not info then
		return ""
	end
	local lines = {info.name}
	lines[#lines + 1] = mineral_line(player, info)
	if info.hot then
		lines[#lines + 1] = core.colorize(BAD, str_machine.hull_slots.has(player, LAVA_PROTECTION)
			and "Hot - heats the hull when drilled" or "Hot - damages the hull when drilled")
	end
	lines[#lines + 1] = status_line(player, info)
	return table.concat(lines, "\n")
end

-- player name -> label shown, crosshair hud id
local labels, crosshairs = {}, {}

local function update(player)
	local name = player:get_player_name()
	local pos = str_mode.get(player) == "vehicle" and not str_machine.is_dead(player)
		and player:get_wielded_item():get_name() == ITEM and str_machine.get_pos(player)
	if pos and not crosshairs[name] then
		crosshairs[name] = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = 1, y = 1}, z_index = 10, text = CROSSHAIR,
		})
	elseif not pos and crosshairs[name] then
		player:hud_remove(crosshairs[name])
		crosshairs[name] = nil
	end
	local label = pos and readout(player, pos) or ""
	if label ~= labels[name] then
		labels[name] = label
		str_hud.set_text(player, HUD, label)
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
		update(player)
	end
end)

str_mode.register_on_change(update)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	labels[name], crosshairs[name] = nil, nil
end)
