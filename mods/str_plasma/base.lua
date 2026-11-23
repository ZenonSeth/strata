local data = str_machine_data.plasma
local torch = data.torch
local MAX_WEAR = 65535

-- Laser item names, which may not share the machine hotbar with the torch
local lasers = {}
for _, def in ipairs(str_machine_data.lasers.lasers) do
	lasers[def.item] = true
end

local cells = {}
for _, def in ipairs(data.cells) do
	cells[def.item] = def
end

local function format_seconds(s)
	return ("%d s"):format(math.floor(s + 0.5))
end

local function cell_text(def, s)
	if s <= 0 then
		return def.description .. "\nEmpty - refill it with uranium in Create Items"
	end
	return ("%s\nPlasma: %s / %s"):format(def.description, format_seconds(s), format_seconds(def.capacity_s))
end

str_plasma.format_seconds = format_seconds

function str_plasma.is_cell(stack)
	return cells[stack:get_name()] ~= nil
end

function str_plasma.capacity(stack)
	local def = cells[stack:get_name()]
	return def and def.capacity_s or 0
end

-- A cell without stored plasma is full
function str_plasma.get_charge(stack)
	local def = cells[stack:get_name()]
	if not def then
		return 0
	end
	local raw = stack:get_meta():get_string("plasma")
	return raw ~= "" and tonumber(raw) or def.capacity_s
end

-- The wear bar only shows the plasma left; it never reaches the point where the tool breaks
function str_plasma.set_charge(stack, s)
	local def = cells[stack:get_name()]
	s = math.max(0, math.min(s, def.capacity_s))
	local meta = stack:get_meta()
	meta:set_string("plasma", tostring(s))
	meta:set_string("description", cell_text(def, s))
	meta:set_string("count_meta", str_lasers.percent_text(s, def.capacity_s))
	stack:set_wear(math.floor(MAX_WEAR * (1 - s / def.capacity_s) + 0.5))
end

-- Seconds of plasma the cell is short of full
function str_plasma.missing(stack)
	local def = cells[stack:get_name()]
	if not def then
		return 0
	end
	local missing = def.capacity_s - str_plasma.get_charge(stack)
	return missing > 1e-6 and missing or 0
end

-- Uranium to fill the cell: refill_uranium per full refill, one unit per started share
function str_plasma.refill_cost(stack)
	local def = cells[stack:get_name()]
	local missing = str_plasma.missing(stack)
	if not def or missing <= 0 then
		return 0
	end
	return math.max(1, math.ceil(missing / def.capacity_s * def.refill_uranium - 1e-6))
end

-- Writes the plasma texts onto a cell made without meta, e.g. a fresh one
function str_plasma.label(stack)
	str_plasma.set_charge(stack, str_plasma.get_charge(stack))
end

function str_plasma.fill(stack)
	str_plasma.set_charge(stack, str_plasma.capacity(stack))
end

-- Machine hotbar indices that hold a plasma cell
function str_plasma.cell_slots(player)
	local slots = {}
	for i, stack in ipairs(player:get_inventory():get_list(str_hotbar.list(player, "vehicle")) or {}) do
		if str_plasma.is_cell(stack) then
			slots[#slots + 1] = i
		end
	end
	return slots
end

-- Takes up to s seconds of plasma from the hotbar cells in order; returns how much it took
local function draw(player, s)
	local inv, hotbar = player:get_inventory(), str_hotbar.list(player, "vehicle")
	local taken = 0
	for _, i in ipairs(str_plasma.cell_slots(player)) do
		local stack = inv:get_stack(hotbar, i)
		local have = str_plasma.get_charge(stack)
		if have > 0 then
			local take = math.min(have, s - taken)
			str_plasma.set_charge(stack, have - take)
			inv:set_stack(hotbar, i, stack)
			taken = taken + take
			if taken >= s then
				break
			end
		end
	end
	return taken
end

local function hotbar_has(player, wanted)
	for _, stack in ipairs(player:get_inventory():get_list(str_hotbar.list(player, "vehicle")) or {}) do
		if wanted(stack:get_name()) then
			return true
		end
	end
	return false
end

local function is_torch(name)
	return name == torch.item
end

local function is_laser(name)
	return lasers[name] == true
end

local function is_cell_name(name)
	return cells[name] ~= nil
end

for _, def in ipairs(data.cells) do
	core.register_tool(def.item, {
		description = cell_text(def, def.capacity_s),
		short_description = def.description,
		inventory_image = "str_plasma_" .. def.name .. ".png",
		on_drop = function(itemstack) return itemstack end,
	})
end

-- Far enough to point at any node on screen from the camera, as for lasers
local POINT_RANGE = 24
local MIN_BURN_TIME = 0.05
local FLAME_WIDTH = 0.18
-- A flame not refreshed for this long removes itself
local FLAME_LINGER = 0.25

core.register_craftitem(torch.item, {
	description = ("%s\nHold to burn through nodes up to tier %d, one at a time, up to %d away\n"
		.. "Ore and gems are left behind as piles\nUses plasma from a cell in the hotbar and heats the machine"):format(
		torch.description, torch.tier, torch.range),
	short_description = torch.description,
	inventory_image = "str_plasma_" .. torch.name .. ".png",
	stack_max = 1,
	range = POINT_RANGE,
	on_drop = function(itemstack) return itemstack end,
})

str_machine.heat.register_capacity(function(player)
	return hotbar_has(player, is_torch) and torch.heat_capacity or 0
end)

str_audio.sfx.register("plasma_burn", {sound = "str_plasma_burn", gain = 0.6})

core.register_entity("str_plasma:flame", {
	initial_properties = {
		visual = "cube", physical = false, pointable = false, static_save = false,
		glow = 14, visual_size = {x = 1, y = FLAME_WIDTH, z = FLAME_WIDTH},
		textures = {"blank.png"},
	},
	on_step = function(self, dtime)
		self.age = (self.age or 0) + dtime
		if self.age >= FLAME_LINGER then
			self.object:remove()
		end
	end,
})

-- player name -> flame object
local flames = {}

local function remove_flame(name)
	local obj = flames[name]
	if obj and obj:get_pos() then
		obj:remove()
	end
	flames[name] = nil
end

local function show_flame(name, from, to)
	local length = vector.distance(from, to)
	if length < 0.05 then
		remove_flame(name)
		return
	end
	local mid = vector.multiply(vector.add(from, to), 0.5)
	local obj = flames[name]
	if not (obj and obj:get_pos()) then
		obj = core.add_entity(mid, "str_plasma:flame")
		flames[name] = obj
		if not obj then
			return
		end
	end
	obj:get_luaentity().age = 0
	obj:set_pos(mid)
	-- Flicker by varying width and brightness every step
	local width = FLAME_WIDTH * (0.8 + math.random() * 0.4)
	local texture = "[fill:16x16:" .. torch.color .. "^[opacity:" .. math.random(200, 255)
	obj:set_properties({
		visual_size = {x = length, y = width, z = width},
		textures = {texture, texture, texture, texture, texture, texture},
	})
	-- Roll a turns +x towards -y (see vector.rotate), so negate the beam angle
	obj:set_rotation(vector.new(0, 0, -math.atan2(to.y - from.y, to.x - from.x)))
end

local function sparks(pos)
	for _ = 1, 2 do
		core.add_particle({
			pos = vector.offset(pos, 0, 0, -0.3),
			velocity = vector.new((math.random() - 0.5) * 4, math.random() * 3, -math.random()),
			acceleration = vector.new(0, -9, 0),
			expirationtime = 0.3 + math.random() * 0.3,
			size = 0.6 + math.random() * 0.6,
			glow = 14,
			texture = "[fill:2x2:#ffd27a",
		})
	end
end

-- The aim point where the camera look crosses the front face of the machine's slice
local function aim_point(player, slice_z)
	local eye = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
	local dir = player:get_look_dir()
	local face_z = slice_z - 0.5
	if dir.z <= 1e-6 or eye.z >= face_z then
		return nil
	end
	return vector.add(eye, vector.multiply(dir, (face_z - eye.z) / dir.z))
end

-- Walks the grid from the machine towards the aim (2D DDA in the slice plane);
-- returns the first solid cell within range (or nil) and the flame end point
local function trace(from, target)
	local dx, dy = target.x - from.x, target.y - from.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 1e-6 then
		return nil, from
	end
	dx, dy = dx / dist, dy / dist
	local cell = vector.round(from)
	local step_x, step_y = dx > 0 and 1 or -1, dy > 0 and 1 or -1
	local t_max_x = dx ~= 0 and (cell.x + 0.5 * step_x - from.x) / dx or math.huge
	local t_max_y = dy ~= 0 and (cell.y + 0.5 * step_y - from.y) / dy or math.huge
	local t_delta_x = dx ~= 0 and math.abs(1 / dx) or math.huge
	local t_delta_y = dy ~= 0 and math.abs(1 / dy) or math.huge
	local function point(t)
		return vector.new(from.x + dx * t, from.y + dy * t, from.z)
	end
	while true do
		local t
		if t_max_x < t_max_y then
			t, cell.x, t_max_x = t_max_x, cell.x + step_x, t_max_x + t_delta_x
		else
			t, cell.y, t_max_y = t_max_y, cell.y + step_y, t_max_y + t_delta_y
		end
		if t > torch.range then
			return nil, point(torch.range)
		end
		local node = core.get_node(cell)
		local def = core.registered_nodes[node.name]
		if node.name == "ignore" or not def then
			return nil, point(t)
		end
		if def.walkable then
			return vector.copy(cell), point(t)
		end
	end
end

-- Burns the node at cell to nothing, leaving its ore or gem as a pile
local function burn_out(player, cell)
	local def = core.registered_nodes[core.get_node(cell).name]
	local material = def.str_material
	local yield = def.str_yield or 1
	if not str_machine.destroy_node(player, cell, torch.tier) then
		return
	end
	if material and str_materials.get(material) then
		str_piles.drop(cell, material, yield)
	end
end

-- player name -> {cell = burning cell or nil, time = seconds on it, warned = popup shown this press}
local states = {}

local function stop(player)
	local name = player:get_player_name()
	local state = states[name]
	if state and state.burning then
		str_audio.sfx.stop_loop(player, "plasma")
	end
	remove_flame(name)
	if state then
		state.burning, state.cell, state.time = nil, nil, 0
	end
end

local function warn(player, state, text)
	if not state.warned then
		state.warned = true
		str_utils.show_popup(player:get_player_name(), text, 2, true)
	end
end

local function burn_step(player, dtime)
	local name = player:get_player_name()
	local state = states[name] or {time = 0}
	states[name] = state
	local control = player:get_player_control()
	local pos = str_mode.get(player) == "vehicle" and not str_machine.is_dead(player)
		and not str_machine.is_surface(player) and is_torch(player:get_wielded_item():get_name())
		and str_machine.get_pos(player)
	if not pos or not control.dig then
		state.warned = nil
		stop(player)
		return
	end
	if not str_lasers.has_mount(player) then
		warn(player, state, "Fit a " .. str_machine_data.lasers.mount.description:lower() .. " in the hull first.")
		return stop(player)
	end
	if hotbar_has(player, is_laser) then
		warn(player, state, "Take the lasers out of the machine hotbar first.")
		return stop(player)
	end
	if str_machine.heat.overheated(player) then
		return stop(player)
	end
	local from = vector.new(pos.x, pos.y, math.floor(pos.z + 0.5))
	local target = aim_point(player, from.z)
	if not target then
		return stop(player)
	end
	local drawn = draw(player, dtime)
	if drawn <= 0 then
		warn(player, state, hotbar_has(player, is_cell_name) and "Out of plasma." or "Carry a plasma cell in the hotbar.")
		return stop(player)
	end
	if str_machine.heat.add(player, torch.heat_per_second * drawn) then
		return stop(player)
	end
	if not state.burning then
		state.burning = true
		str_audio.sfx.start_loop(player, "plasma", "plasma_burn")
	end
	local cell, tip = trace(from, target)
	show_flame(name, from, tip)
	if not cell then
		state.cell, state.time = nil, 0
		return
	end
	sparks(tip)
	if not (state.cell and vector.equals(state.cell, cell)) then
		state.cell, state.time = cell, 0
	end
	local def = core.registered_nodes[core.get_node(cell).name]
	if def.diggable == false or (def.str_tier or 0) > torch.tier then
		return
	end
	state.time = state.time + drawn
	if state.time >= math.max(MIN_BURN_TIME, (def.str_hardness or 1) / torch.dig_speed) then
		burn_out(player, cell)
		state.cell, state.time = nil, 0
	end
end

-- The crosshair shows only while the torch is wielded in the machine
local crosshairs = {}

-- Halfway to white, so the crosshair shows against dark rock
local function lighten(color)
	local r, g, b = color:match("#(%x%x)(%x%x)(%x%x)")
	local function mix(c)
		return math.floor((tonumber(c, 16) + 255) / 2 + 0.5)
	end
	return ("#%02x%02x%02x"):format(mix(r), mix(g), mix(b))
end

local function update_crosshair(player)
	local name = player:get_player_name()
	local want = str_mode.get(player) == "vehicle" and not str_machine.is_dead(player)
		and not str_machine.is_surface(player) and is_torch(player:get_wielded_item():get_name())
	if want and not crosshairs[name] then
		crosshairs[name] = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = 1, y = 1}, z_index = 10,
			text = "str_lasers_crosshair.png^[multiply:" .. lighten(torch.color),
		})
	elseif not want and crosshairs[name] then
		player:hud_remove(crosshairs[name])
		crosshairs[name] = nil
	end
end

core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		update_crosshair(player)
		burn_step(player, dtime)
	end
end)

-- The torch and lasers may not share the machine hotbar; an item swapped out of the target slot does not count
core.register_allow_player_inventory_action(function(player, action, inv, info)
	local hotbar = str_hotbar.list(player, "vehicle")
	local stack, index
	if action == "move" and info.to_list == hotbar and info.from_list ~= hotbar then
		stack, index = inv:get_stack(info.from_list, info.from_index), info.to_index
	elseif action == "put" and info.listname == hotbar then
		stack, index = info.stack, info.index
	else
		return
	end
	local clash = is_torch(stack:get_name()) and is_laser or is_laser(stack:get_name()) and is_torch
	if not clash then
		return
	end
	for i, other in ipairs(inv:get_list(hotbar) or {}) do
		if i ~= index and clash(other:get_name()) then
			str_utils.show_popup(player:get_player_name(), "The plasma torch and lasers cannot share the machine hotbar.", 2, true)
			return 0
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	remove_flame(name)
	states[name], crosshairs[name] = nil, nil
end)
