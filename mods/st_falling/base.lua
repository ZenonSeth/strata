local GRAVITY = tonumber(core.settings:get("movement_gravity")) or 9.81
local TRANSFER = st_utils.constants.rock_momentum_transfer
local PUFF_COUNT, PUFF_SCALE = 14, 0.5
-- Machine collision box (see st_machine): half width and the vertical extent below its position
local MACHINE_HALF, MACHINE_BELOW = 0.3, 0.5
local FALLBACK_TEXTURE = "blank.png"

local function puff_texture(name)
	local def = core.registered_nodes[name]
	local tile = def and def.tiles and def.tiles[1]
	if type(tile) == "table" then
		tile = tile.name
	end
	return tile or FALLBACK_TEXTURE
end

local function puff(pos, name)
	st_utils.puff(pos, PUFF_COUNT, PUFF_SCALE, puff_texture(name), false)
end

-- True if the swept rock box overlaps the machine box
local function hits_machine(rock_pos, prev_y, machine_pos)
	if math.abs(rock_pos.x - machine_pos.x) >= 0.5 + MACHINE_HALF
			or math.abs(rock_pos.z - machine_pos.z) >= 0.5 + MACHINE_HALF then
		return false
	end
	local low = math.min(rock_pos.y, prev_y) - 0.5
	local high = math.max(rock_pos.y, prev_y) + 0.5
	return low < machine_pos.y and high > machine_pos.y - MACHINE_BELOW
end

local function crush(machine, player, vy)
	local vel = machine:get_velocity()
	vel.y = vel.y + vy * TRANSFER
	machine:set_velocity(vel)
	st_machine.hull.damage(player, st_utils.impact_damage(-vy))
end

core.register_entity("st_falling:rock", {
	initial_properties = {
		visual = "node",
		node = {name = "air"},
		physical = true,
		collide_with_objects = false,
		collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		pointable = false,
		visual_size = {x = 1, y = 1, z = 1},
	},

	node = nil,

	set_node = function(self, node)
		if not core.registered_nodes[node.name] then
			self.object:remove()
			return
		end
		self.node = node
		self.object:set_properties({node = node})
	end,

	get_staticdata = function(self)
		return self.node and core.serialize(self.node) or ""
	end,

	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		self.object:set_acceleration(vector.new(0, -GRAVITY, 0))
		self.prev_y = self.object:get_pos().y
		local node = staticdata ~= "" and core.deserialize(staticdata)
		if node then
			self:set_node(node)
		end
	end,

	land = function(self, node_pos)
		local above = vector.offset(node_pos, 0, 1, 0)
		local def = core.registered_nodes[core.get_node(above).name]
		if def and def.buildable_to then
			core.set_node(above, self.node)
			return true
		end
		return false
	end,

	on_step = function(self, dtime, moveresult)
		if not self.node then
			return
		end
		local pos = self.object:get_pos()
		local vy = self.object:get_velocity().y
		local prev_y = self.prev_y or pos.y
		self.prev_y = pos.y
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 3 + math.abs(vy) * dtime)) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "st_machine:machine" then
				local player = st_machine.owner(obj)
				if player and hits_machine(pos, prev_y, obj:get_pos()) then
					puff(pos, self.node.name)
					self.object:remove()
					crush(obj, player, vy)
					return
				end
			end
		end
		if not moveresult or not moveresult.touching_ground then
			return
		end
		for _, info in ipairs(moveresult.collisions) do
			if info.type == "node" and info.axis == "y" then
				if not self:land(info.node_pos) then
					puff(pos, self.node.name)
				end
				self.object:remove()
				return
			end
		end
	end,
})

-- Turn the node at pos into a falling rock
function st_falling.spawn(pos, node)
	local obj = core.add_entity(pos, "st_falling:rock", core.serialize(node))
	return obj
end

local function can_fall(pos)
	local node = core.get_node(pos)
	if core.get_item_group(node.name, "falling_node") == 0 then
		return false
	end
	local below = core.get_node_or_nil(vector.offset(pos, 0, -1, 0))
	local def = below and core.registered_nodes[below.name]
	return def ~= nil and not def.walkable
end

-- Drop the unsupported falling nodes in the column above pos
function st_falling.check(pos)
	local p = vector.offset(pos, 0, 1, 0)
	while can_fall(p) do
		local node = core.get_node(p)
		core.remove_node(p)
		st_falling.spawn(p, node)
		p = vector.offset(p, 0, 1, 0)
	end
end

-- Disabled: rocks are obstacles, not hazards
-- st_machine.register_on_dig(function(_, pos)
-- 	st_falling.check(pos)
-- end)
