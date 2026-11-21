-- Wooden chair: one node on the floor, its back away from the player who places it. Made at the table saw.
-- Boxes and textures from tools/gen_chair.py

local BOXES = {
	{-11/32, -3/32, -11/32, 11/32, 0, 11/32},
	{-10/32, -16/32, -10/32, -7/32, -3/32, -7/32},
	{7/32, -16/32, -10/32, 10/32, -3/32, -7/32},
	{-10/32, -16/32, 7/32, -7/32, 16/32, 10/32},
	{7/32, -16/32, 7/32, 10/32, 16/32, 10/32},
	{-7/32, 10/32, 7/32, 7/32, 15/32, 9/32},
	{-7/32, 4/32, 7/32, 7/32, 7/32, 9/32},
	{-7/32, -12/32, -10/32, 7/32, -10/32, -8/32},
	{-10/32, -11/32, -7/32, -8/32, -9/32, 7/32},
	{8/32, -11/32, -7/32, 10/32, -9/32, 7/32},
}

core.register_entity("str_furnish:seat", {
	initial_properties = {
		visual = "sprite", textures = {"blank.png"}, is_visible = false,
		physical = false, pointable = false, static_save = false,
	},
})

local SEAT_DROP = 0.3
local SIT_EYE = vector.new(0, -3.5, 0)
local MOVE_KEYS = {"up", "down", "left", "right", "jump"}
-- player name -> {obj, pos (chair), back (where the player stood)}
local sitting = {}

local function stand_up(player)
	local name = player:get_player_name()
	local seat = sitting[name]
	if not seat then
		return
	end
	sitting[name] = nil
	player:set_detach()
	player:set_eye_offset(vector.zero())
	if seat.obj:is_valid() then
		seat.obj:remove()
	end
	player:set_pos(seat.back)
end

local function sit_down(player, pos, node)
	local name = player:get_player_name()
	if sitting[name] then
		return
	end
	local obj = core.add_entity(vector.offset(pos, 0, -SEAT_DROP, 0), "str_furnish:seat")
	if not obj then
		return
	end
	sitting[name] = {obj = obj, pos = vector.copy(pos), back = player:get_pos()}
	player:set_attach(obj)
	player:set_eye_offset(SIT_EYE)
	player:set_look_horizontal(math.pi - node.param2 * math.pi / 2)
end

core.register_globalstep(function()
	for name, seat in pairs(sitting) do
		local player = core.get_player_by_name(name)
		local moved = false
		if player then
			local control = player:get_player_control()
			for _, key in ipairs(MOVE_KEYS) do
				moved = moved or control[key]
			end
		end
		if not player or moved or not core.get_node(seat.pos).name:find("^str_furnish:chair")
				or str_mode.get(player) ~= "foot" then
			if player then
				stand_up(player)
			else
				sitting[name] = nil
				if seat.obj:is_valid() then
					seat.obj:remove()
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	stand_up(player)
end)

core.register_on_dieplayer(function(player)
	stand_up(player)
end)

str_furnish.register_piece("chair", {
	use = sit_down,
	material = "wood",
	item = "str_furnish:chair_item",
	description = "Wooden chair",
	info = "Place it in your workshop on the floor\nRight-click it to sit, move to get up\nSneak and punch it to pick it up",
	from = {oak_planks = 4},
	station = "table_saw",
	image = "str_furnish_chair.png",
	variants = {
		{id = "floor", support = str_groups.FLOOR, cells = {
			{node = "chair", offset = vector.zero(), boxes = BOXES,
				selection = {{-11/32, -16/32, -11/32, 11/32, 16/32, 11/32}},
				collision = {{-11/32, -16/32, -11/32, 11/32, 0, 11/32}, {-10/32, 0, 7/32, 10/32, 16/32, 10/32}}},
		}},
	},
})
