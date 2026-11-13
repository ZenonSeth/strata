local FORMNAME = "st_signs:main"
local ITEM = "st_signs:sign"
local META_NODE, META_PARAM2 = "st_signs:backing", "st_signs:backing_param2"
local SLICE_Z = st_utils.constants.slice_z

local esc = core.formspec_escape

-- Sign types in picker order; the first is what a fresh sign shows. Row 1 holds the markings, row 2 the circles
local TYPES = {
	{id = "up", description = "Up arrow", row = 1},
	{id = "down", description = "Down arrow", row = 1},
	{id = "left", description = "Left arrow", row = 1},
	{id = "right", description = "Right arrow", row = 1},
	{id = "warning", description = "Warning", row = 1},
	{id = "danger", description = "Danger", row = 1},
	{id = "circle_red", description = "Red circle", row = 2},
	{id = "circle_yellow", description = "Yellow circle", row = 2},
	{id = "circle_green", description = "Green circle", row = 2},
	{id = "circle_blue", description = "Blue circle", row = 2},
	{id = "circle_orange", description = "Orange circle", row = 2},
	{id = "circle_purple", description = "Purple circle", row = 2},
}

local COLUMNS, ROWS, BUTTON, GAP, PAD = 6, 2, 1.4, 0.3, 0.9
local ACTION_W, ACTION_GAP = 3, 0.4
local WIDTH = COLUMNS * BUTTON + (COLUMNS - 1) * GAP + 2 * PAD
local GRID_Y = st_gui.CONTENT_Y + 0.2
local MESSAGE_Y = GRID_Y + ROWS * (BUTTON + GAP) + 0.2
local HEIGHT = MESSAGE_Y + 1.9

local type_of_node = {}
for _, sign in ipairs(TYPES) do
	local name = "st_signs:" .. sign.id
	type_of_node[name] = sign.id
	core.register_node(name, {
		description = "Sign (" .. sign.description .. ")",
		tiles = {"st_signs_" .. sign.id .. ".png"},
		groups = {not_in_creative_inventory = 1},
		diggable = false,
		is_ground_content = false,
		st_interact = "sign",
	})
end

local rock = {}
for _, stratum in ipairs(st_nodes.data.strata) do
	rock["st_nodes:" .. stratum.name] = true
end

-- Plain backing rock; air, ores, liquids, the surface cover and other signs all fail
local function is_backing(pos)
	return rock[core.get_node(pos).name] == true
end

-- Node of the backing cell behind the machine, or nil if the machine is not driving
local function target_pos(player)
	local pos = st_machine.get_pos(player)
	return pos and vector.round(vector.new(pos.x, pos.y, SLICE_Z + 1))
end

-- Positions of the sign each player has open
local open_at = {}

local function build(player_name, message)
	local pos = open_at[player_name]
	local current = type_of_node[core.get_node(pos).name]
	local fs = {st_gui.header(WIDTH, HEIGHT, "Sign")}
	local column = {0, 0}
	for _, sign in ipairs(TYPES) do
		local x = PAD + column[sign.row] * (BUTTON + GAP)
		local y = GRID_Y + (sign.row - 1) * (BUTTON + GAP)
		column[sign.row] = column[sign.row] + 1
		if sign.id == current then
			fs[#fs + 1] = ("box[%g,%g;%g,%g;#e0a020]"):format(x - 0.08, y - 0.08, BUTTON + 0.16, BUTTON + 0.16)
		end
		fs[#fs + 1] = ("image_button[%g,%g;%g,%g;%s;type_%s;]"):format(x, y, BUTTON, BUTTON,
			esc("st_signs_" .. sign.id .. ".png"), sign.id)
		fs[#fs + 1] = ("tooltip[type_%s;%s]"):format(sign.id, esc(sign.description))
	end
	if message then
		fs[#fs + 1] = ("label[0.4,%g;%s]"):format(MESSAGE_Y, esc(message))
	end
	local left = (WIDTH - 2 * ACTION_W - ACTION_GAP) / 2
	fs[#fs + 1] = ("button[%g,%g;%g,0.8;pickup;Pick up]"):format(left, HEIGHT - 1.2, ACTION_W)
	fs[#fs + 1] = ("button_exit[%g,%g;%g,0.8;done;Done]"):format(left + ACTION_W + ACTION_GAP, HEIGHT - 1.2, ACTION_W)
	return table.concat(fs)
end

local function show(player_name, message)
	core.show_formspec(player_name, FORMNAME, build(player_name, message))
end

local function open(player, pos)
	open_at[player:get_player_name()] = pos
	show(player:get_player_name())
end

st_interact.register("sign", {label = "Sign", on_use = open})

local function pick_up(player, pos)
	local name = player:get_player_name()
	local inv = player:get_inventory()
	if not inv:room_for_item("main", ItemStack(ITEM)) then
		show(name, "Your inventory is full.")
		return
	end
	local meta = core.get_meta(pos)
	local backing = meta:get_string(META_NODE)
	if backing == "" then
		backing = "st_nodes:" .. st_nodes.data.strata[1].name
	end
	local param2 = meta:get_int(META_PARAM2)
	inv:add_item("main", ItemStack(ITEM))
	core.set_node(pos, {name = backing, param2 = param2})
	open_at[name] = nil
	core.close_formspec(name, FORMNAME)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	if fields.quit then
		open_at[name] = nil
		return
	end
	local pos = open_at[name]
	if not pos or not type_of_node[core.get_node(pos).name] then
		open_at[name] = nil
		core.close_formspec(name, FORMNAME)
		return
	end
	if fields.pickup then
		pick_up(player, pos)
		return
	end
	for field in pairs(fields) do
		local id = field:match("^type_(.+)$")
		if id and type_of_node["st_signs:" .. id] then
			core.swap_node(pos, {name = "st_signs:" .. id})
			show(name)
			return
		end
	end
end)

core.register_on_leaveplayer(function(player)
	open_at[player:get_player_name()] = nil
end)

local function place(player, pos)
	local old = core.get_node(pos)
	core.set_node(pos, {name = "st_signs:" .. TYPES[1].id})
	local meta = core.get_meta(pos)
	meta:set_string(META_NODE, old.name)
	meta:set_int(META_PARAM2, old.param2)
	open(player, pos)
end

core.register_craftitem(ITEM, {
	description = "Sign\nPlaced behind the machine; interact with the interact key to change or pick up",
	short_description = "Sign",
	inventory_image = "st_signs_up.png",
	stack_max = 200,
	on_use = function(itemstack, user)
		if not user or st_mode.get(user) ~= "vehicle" or st_machine.is_dead(user) then
			return
		end
		local pos = target_pos(user)
		if not pos then
			return
		end
		if not (is_backing(pos) and is_backing(vector.offset(pos, 0, -1, 0))) then
			st_utils.show_popup(user:get_player_name(), "A sign can't be placed here.", 2, true)
			return
		end
		place(user, pos)
		itemstack:take_item()
		return itemstack
	end,
	on_drop = function(itemstack) return itemstack end,
})
