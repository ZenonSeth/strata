-- The launch workshop: a placed site takes one set of materials at its window, then becomes the two-node building
local theme = str_gui.theme
local esc = core.formspec_escape
local FORM = "str_rocket:workshop"
local SITE_INTERACT, BUILT_INTERACT = "rocket_workshop_site", "rocket_workshop"
local STRIKE_GAP = 0.25

-- Taken from shop storage, then the cargo hold
local BUILD_FROM = {
	pine_planks = 24, steel = 20, nickel_steel = 8, bronze = 6, copper_wire = 20, gold_wire = 6,
	platinum_alloy = 4, lens_glass = 2,
}
str_rocket.workshop_from = BUILD_FROM
str_rocket.SITE_INTERACT = SITE_INTERACT
-- Taller than the machine's surface step height (1.1), so it cannot drive onto a site or the workshop
str_rocket.SITE_COLLISION = {type = "fixed", fixed = {{-0.5, -0.5, -0.5, 0.5, 1, 0.5}}}

local NEAR_BOXES = {
	{-15/32, 5/32, -15/32, 15/32, 8/32, 15/32},
	{-13/32, -14/32, -13/32, 15/32, 5/32, 13/32},
	{-1/32, 8/32, -9/32, 6/32, 12/32, -2/32},
	{15/32, -8/32, -8/32, 16/32, -3/32, -3/32},
	{-16/32, -16/32, -16/32, 16/32, -14/32, 16/32},
}
local FAR_BOXES = {
	{-14/32, -8/32, -7/32, 14/32, 8/32, 7/32},
	{-14/32, -6/32, -9/32, 14/32, 6/32, 9/32},
	{-14/32, -4/32, -10/32, 14/32, 4/32, 10/32},
	{-15/32, -5/32, -6/32, 15/32, 5/32, 6/32},
	{-2/32, 8/32, -2/32, 2/32, 11/32, 2/32},
	{-11/32, -14/32, -10/32, -7/32, -8/32, 10/32},
	{7/32, -14/32, -10/32, 11/32, -8/32, 10/32},
	{-16/32, -8/32, -8/32, -14/32, -3/32, -3/32},
	{-16/32, -16/32, -16/32, 16/32, -14/32, 16/32},
}

-- One node per footprint cell, in the same order as the site's cells (-X, then +X)
str_rocket.workshop_nodes = {}
for i, part in ipairs({{"near", NEAR_BOXES}, {"far", FAR_BOXES}}) do
	local name = "str_rocket:support_" .. part[1]
	local prefix = "str_rocket_support_" .. part[1] .. "_"
	core.register_node(name, {
		description = "Launch workshop",
		drawtype = "nodebox",
		node_box = {type = "fixed", fixed = part[2]},
		collision_box = str_rocket.SITE_COLLISION,
		tiles = {prefix .. "top.png", prefix .. "bottom.png", prefix .. "left.png", prefix .. "right.png",
			prefix .. "back.png", prefix .. "front.png"},
		paramtype = "light",
		sunlight_propagates = true,
		pointable = false,
		diggable = false,
		buildable_to = false,
		is_ground_content = false,
		drop = "",
		groups = {not_in_creative_inventory = 1, str_rocket = 1},
		str_interact = BUILT_INTERACT,
	})
	str_rocket.workshop_nodes[i] = name
end

local function held_materials(player)
	local held = str_storage.get(player)
	for material, count in pairs(str_machine.cargo.get(player)) do
		held[material] = (held[material] or 0) + count
	end
	return held
end

local function has_materials(player)
	local held = held_materials(player)
	for material, need in pairs(BUILD_FROM) do
		if (held[material] or 0) < need then
			return false
		end
	end
	return true
end

local function take_materials(player)
	for material, amount in pairs(BUILD_FROM) do
		amount = amount - str_storage.remove(player, material, amount)
		if amount > 0 then
			str_machine.cargo.remove(player, material, amount)
		end
	end
end

-- Whether pos is a cell of the player's own placed launch workshop
local function owns(player, pos)
	local anchor = str_rocket.data(player:get_player_name()).support
	return anchor ~= nil and pos.y == anchor.y and pos.z == anchor.z and (pos.x == anchor.x or pos.x == anchor.x + 1)
end

local function sorted_materials()
	local names = {}
	for material in pairs(BUILD_FROM) do
		names[#names + 1] = material
	end
	table.sort(names)
	return names
end

local function site_form(player)
	local w, x, pad = 8, 0.4, 0.4
	local y = str_gui.CONTENT_Y + 0.2
	local inner_w = w - 2 * x
	local held = held_materials(player)
	local rows = {}
	for i, material in ipairs(sorted_materials()) do
		local need, have = BUILD_FROM[material], held[material] or 0
		local def, short = str_materials.get(material), have < need
		rows[i] = {icon = def.icon, text = ("%d %s"):format(need, def.description), color = short and theme.muted or nil,
			right = tostring(have), right_color = short and theme.danger or nil}
	end
	local rows_y = y + str_gui.INFO_IMAGE + 0.3
	local bottom = rows_y + (#rows + 1) * str_gui.ICON_ROW_H + 0.3 + str_gui.ACTION_H
	local ready = has_materials(player)
	return table.concat({
		str_gui.header(w, bottom + pad, "Launch workshop site"),
		str_gui.info_title(x, y, inner_w, {item = str_rocket.blueprint_items.support},
			"<b><style size=18>Launch workshop</style></b>\nMakes rocket fuel and launch parts once built"),
		str_gui.icon_rows(x, rows_y, inner_w, {"Needs", "Have"}, rows),
		str_gui.action_row(x, bottom, inner_w, ready and "Ready to build" or "Missing materials",
			ready and theme.text or theme.muted, ready and {{"build", "Build"}} or nil),
	})
end

local function built_form()
	local w, y = 8, str_gui.CONTENT_Y
	return table.concat({
		str_gui.header(w, y + 1.6, "Launch workshop"),
		str_gui.info_text(0.4, y, w - 0.8, 1.2, esc("Nothing to make here yet.")),
	})
end

local function play_build_strikes(player)
	local name = player:get_player_name()
	str_audio.sfx.play("upgrade_strike", {player = player})
	core.after(STRIKE_GAP, function()
		local p = core.get_player_by_name(name)
		if p then
			str_audio.sfx.play("upgrade_strike", {player = p})
		end
	end)
end

-- A soft burst of dust pushed out from each cell
function str_rocket.build_burst(list)
	for _, pos in ipairs(list) do
		core.add_particlespawner({
			amount = 40,
			time = 0.25,
			pos = {min = vector.offset(pos, -0.5, -0.5, -0.5), max = vector.offset(pos, 0.5, 0.4, 0.5)},
			vel = {min = vector.new(-1.5, 0.5, -1.5), max = vector.new(1.5, 2.5, 1.5)},
			attract = {kind = "point", strength = {min = -2, max = -3}, origin = vector.offset(pos, 0, -0.5, 0)},
			drag = vector.new(1.5, 1.5, 1.5),
			acc = vector.new(0, -0.8, 0),
			exptime = {min = 1, max = 1.8},
			size = {min = 3, max = 6},
			texture = {name = "str_machine_puff.png^[multiply:#b5a68a", blend = "alpha",
				alpha_tween = {0.9, 0}, scale_tween = {0.6, 1.6}},
		})
	end
end

local function build(player)
	local name = player:get_player_name()
	local d = str_rocket.data(name)
	if not d.support or d.support_built or not has_materials(player) then
		return
	end
	take_materials(player)
	d.support_built = true
	str_rocket.save(name)
	str_rocket.restore("support", d.support, str_rocket.workshop_nodes)
	str_rocket.build_burst({d.support, vector.offset(d.support, 1, 0, 0)})
	play_build_strikes(player)
	str_utils.show_popup(name, "Launch workshop built", 3)
end

local function open(form)
	return function(player, pos)
		local name = player:get_player_name()
		if not owns(player, pos) then
			str_utils.show_popup(name, "This launch workshop belongs to someone else", 2, true)
			return
		end
		core.show_formspec(name, FORM, form(player))
	end
end

str_interact.register(SITE_INTERACT, {label = "Launch workshop site", on_use = open(site_form)})
str_interact.register(BUILT_INTERACT, {label = "Launch workshop", on_use = open(built_form)})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then
		return
	end
	if fields.build then
		core.close_formspec(player:get_player_name(), FORM)
		build(player)
	end
	return true
end)
