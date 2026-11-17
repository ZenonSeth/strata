local data = str_machine_data.lasers
local MAX_WEAR = 65535

-- kJ as kJ, MJ or GJ, e.g. 2500 -> "2.5 MJ"
function str_lasers.format_energy(kj)
	if kj >= 1e6 then
		return ("%.3g GJ"):format(kj / 1e6)
	elseif kj >= 1e3 then
		return ("%.3g MJ"):format(kj / 1e3)
	end
	return ("%.3g kJ"):format(kj)
end

local batteries = {}
for _, def in ipairs(data.batteries) do
	batteries[def.item] = def
end

local function battery_text(def, kj)
	return ("%s\nCharge: %s / %s"):format(def.description, str_lasers.format_energy(kj),
		str_lasers.format_energy(def.capacity_kj))
end

function str_lasers.is_battery(stack)
	return batteries[stack:get_name()] ~= nil
end

-- A battery without stored charge is full
function str_lasers.get_charge(stack)
	local def = batteries[stack:get_name()]
	if not def then
		return 0
	end
	local raw = stack:get_meta():get_string("charge")
	return raw ~= "" and tonumber(raw) or def.capacity_kj
end

-- The wear bar only shows the charge; it never reaches the point where the tool breaks
function str_lasers.set_charge(stack, kj)
	local def = batteries[stack:get_name()]
	kj = math.max(0, math.min(kj, def.capacity_kj))
	local meta = stack:get_meta()
	meta:set_string("charge", tostring(kj))
	meta:set_string("description", battery_text(def, kj))
	stack:set_wear(math.floor(MAX_WEAR * (1 - kj / def.capacity_kj) + 0.5))
end

-- Takes kj from the first hotbar battery that holds enough; false if none does
function str_lasers.draw(player, kj)
	local inv = player:get_inventory()
	for i, stack in ipairs(inv:get_list("main") or {}) do
		if str_lasers.is_battery(stack) and str_lasers.get_charge(stack) >= kj then
			str_lasers.set_charge(stack, str_lasers.get_charge(stack) - kj)
			inv:set_stack("main", i, stack)
			return true
		end
	end
	return false
end

function str_lasers.capacity(stack)
	local def = batteries[stack:get_name()]
	return def and def.capacity_kj or 0
end

-- Hotbar indices that hold a battery
function str_lasers.battery_slots(player)
	local slots = {}
	for i, stack in ipairs(player:get_inventory():get_list("main") or {}) do
		if str_lasers.is_battery(stack) then
			slots[#slots + 1] = i
		end
	end
	return slots
end

function str_lasers.has_mount(player)
	return str_machine.hull_slots.has(player, data.mount.item)
end

for _, def in ipairs(data.batteries) do
	core.register_tool(def.item, {
		description = battery_text(def, def.capacity_kj),
		short_description = def.description,
		inventory_image = "str_lasers_" .. def.name .. ".png",
		on_drop = function(itemstack) return itemstack end,
	})
end

local function has_battery(player)
	for _, stack in ipairs(player:get_inventory():get_list("main") or {}) do
		if str_lasers.is_battery(stack) then
			return true
		end
	end
	return false
end

-- Far enough to point at any node on screen from the camera
local POINT_RANGE = 24
local COOLDOWN_US = 500000
local BEAM_TIME = 0.15
local BEAM_WIDTH = 0.12
local SMOKE_TIME = 0.5

local lasers = {}
for _, def in ipairs(data.lasers) do
	lasers[def.item] = def
	core.register_craftitem(def.item, {
		description = ("%s\nRange %d, breaks nodes up to tier %d\nUses %s per shot"):format(def.description,
			def.range, def.tier, str_lasers.format_energy(def.shot_kj)),
		short_description = def.description,
		inventory_image = "str_lasers_" .. def.name .. ".png",
		stack_max = 1,
		range = POINT_RANGE,
		on_drop = function(itemstack) return itemstack end,
	})
end

str_audio.sfx.register("laser_shot", {sound = "str_lasers_shot", max_hear_distance = 32})

core.register_entity("str_lasers:beam", {
	initial_properties = {
		visual = "cube", physical = false, pointable = false, static_save = false,
		glow = 14, visual_size = {x = 1, y = BEAM_WIDTH, z = BEAM_WIDTH},
		textures = {"blank.png"},
	},
	on_step = function(self, dtime)
		self.age = (self.age or 0) + dtime
		if self.age >= BEAM_TIME then
			self.object:remove()
		end
	end,
})

local function show_beam(from, to, color)
	local length = vector.distance(from, to)
	if length < 0.05 then
		return
	end
	local obj = core.add_entity(vector.multiply(vector.add(from, to), 0.5), "str_lasers:beam")
	if not obj then
		return
	end
	local texture = "[fill:16x16:" .. color
	obj:set_properties({
		visual_size = {x = length, y = BEAM_WIDTH, z = BEAM_WIDTH},
		textures = {texture, texture, texture, texture, texture, texture},
	})
	-- Roll a turns +x towards -y (see vector.rotate), so negate the beam angle
	obj:set_rotation(vector.new(0, 0, -math.atan2(to.y - from.y, to.x - from.x)))
	local steps = math.max(1, math.floor(length * 2))
	for i = 0, steps do
		local pos = vector.add(from, vector.multiply(vector.subtract(to, from), i / steps))
		core.add_particle({
			pos = vector.offset(pos, (math.random() - 0.5) * 0.3, (math.random() - 0.5) * 0.3, -0.3),
			velocity = vector.new((math.random() - 0.5) * 0.3, 0.6 + math.random() * 0.6, 0),
			expirationtime = SMOKE_TIME,
			size = 2 + math.random() * 2,
			texture = {name = "str_machine_puff.png^[multiply:#9a9a9a", blend = "alpha",
				alpha_tween = {0.8, 0}, scale_tween = {0.6, 1.4}},
			collisiondetection = true,
			collision_removal = true,
		})
	end
end

-- Breaks one cell of the beam; false if the beam stops there
local function hit(player, cell, def)
	local node = core.get_node(cell)
	local node_def = core.registered_nodes[node.name]
	if node.name == "ignore" or not node_def then
		return false
	end
	if not node_def.walkable then
		return true
	end
	local material = node_def.str_material
	local gem = material and str_materials.get(material) and str_materials.get(material).kind == "gem"
	if not str_machine.destroy_node(player, cell, def.tier) then
		return false
	end
	if gem then
		str_piles.drop(cell, material, node_def.str_yield or 1)
	end
	return true
end

-- Walks the grid from the machine towards the target cell (2D DDA in the slice plane); returns the beam end point
local function trace(player, from, target, def)
	local dx, dy = target.x - from.x, target.y - from.y
	local dist = math.sqrt(dx * dx + dy * dy)
	if dist < 1e-6 then
		return from
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
		if t > def.range then
			return point(def.range)
		end
		if not hit(player, cell, def) then
			return point(t)
		end
		if cell.x == target.x and cell.y == target.y then
			return point(math.min(dist, def.range))
		end
	end
end

local last_shot = {}

local function fire(player, def, target)
	local pos = str_machine.get_pos(player)
	if not pos or str_mode.get(player) ~= "vehicle" or str_machine.is_dead(player) then
		return
	end
	local from = vector.new(pos.x, pos.y, math.floor(pos.z + 0.5))
	if target.z ~= from.z then
		return
	end
	local name = player:get_player_name()
	local now = core.get_us_time()
	if last_shot[name] and now - last_shot[name] < COOLDOWN_US then
		return
	end
	last_shot[name] = now
	if not str_lasers.has_mount(player) then
		str_utils.show_popup(name, "Fit a " .. data.mount.description:lower() .. " in the hull first.", 2, true)
		return
	end
	if not str_lasers.draw(player, def.shot_kj) then
		str_utils.show_popup(name, has_battery(player) and "Battery too low." or "Carry a battery in the hotbar.", 2, true)
		return
	end
	str_audio.sfx.play("laser_shot", {pos = from})
	show_beam(from, trace(player, from, target, def), def.color)
end

core.register_on_punchnode(function(pos, _, puncher)
	if not puncher or not puncher:is_player() then
		return
	end
	local def = lasers[puncher:get_wielded_item():get_name()]
	if def then
		fire(puncher, def, pos)
	end
end)

-- The crosshair shows only while a laser is wielded in the machine
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
	local def = str_mode.get(player) == "vehicle" and not str_machine.is_dead(player)
		and lasers[player:get_wielded_item():get_name()]
	local shown = crosshairs[name]
	if shown and shown.item == (def and def.item) then
		return
	end
	if shown then
		player:hud_remove(shown.id)
		crosshairs[name] = nil
	end
	if def then
		crosshairs[name] = {item = def.item, id = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = 1, y = 1}, z_index = 10,
			text = "str_lasers_crosshair.png^[multiply:" .. lighten(def.color),
		})}
	end
end

core.register_globalstep(function()
	for _, player in ipairs(core.get_connected_players()) do
		update_crosshair(player)
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	crosshairs[name], last_shot[name] = nil, nil
end)
