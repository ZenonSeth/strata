-- Ceiling lamp: a small body in the top centre of the node, plus an arm toward each neighbouring
-- lamp (connected nodebox), so single lamps and bars use the same node. Textures from tools/gen_lamp.py
-- Variants: bright (light 14), dim (light 10), flickering (light 10, goes dark now and then)

local register_node = st_interior.register_node

local GROUP = "st_interior_ceiling_lamp"
local ON_TIME = {10, 20}   -- seconds lit between flickers
local OFF_TIME = {1, 2}    -- seconds dark during a flicker

local function lamp_box()
	return {
		type = "connected",
		fixed = {-6/32, 12/32, -6/32, 6/32, 16/32, 6/32},
		connect_left = {-16/32, 12/32, -6/32, -6/32, 16/32, 6/32},
		connect_right = {6/32, 12/32, -6/32, 16/32, 16/32, 6/32},
		connect_front = {-6/32, 12/32, -16/32, 6/32, 16/32, -6/32},
		connect_back = {-6/32, 12/32, 6/32, 6/32, 16/32, 16/32},
	}
end

local function lamp_tiles(bottom)
	return {
		"st_interior_lamp_top.png", bottom or "st_interior_lamp_bottom.png",
		"st_interior_lamp_left.png", "st_interior_lamp_right.png",
		"st_interior_lamp_back.png", "st_interior_lamp_front.png",
	}
end

local function register_lamp(name, description, light, extra)
	local def = {
		description = description,
		drawtype = "nodebox",
		paramtype = "light",
		light_source = light,
		tiles = lamp_tiles(),
		node_box = lamp_box(),
		selection_box = lamp_box(),
		connects_to = {"group:" .. GROUP},
		groups = {[GROUP] = 1},
	}
	for k, v in pairs(extra or {}) do
		def[k] = v
	end
	register_node(name, def)
end

register_lamp("lamp_ceiling", "Ceiling lamp (bright)", 14)
register_lamp("lamp_ceiling_dim", "Ceiling lamp (dim)", 10)

-- Flickering: the lit and the dark variant swap with a node timer
local LIT = "st_interior:lamp_ceiling_flicker"
local DARK = "st_interior:lamp_ceiling_flicker_off"

local function random_time(range)
	return range[1] + math.random() * (range[2] - range[1])
end

local function start_timer(pos, range)
	core.get_node_timer(pos):start(random_time(range))
end

local function flicker(pos)
	local node = core.get_node(pos)
	if node.name == LIT then
		node.name = DARK
		core.swap_node(pos, node)
		start_timer(pos, OFF_TIME)
	else
		node.name = LIT
		core.swap_node(pos, node)
		start_timer(pos, ON_TIME)
	end
	return false
end

register_lamp("lamp_ceiling_flicker", "Ceiling lamp (flickering)", 10, {
	on_construct = function(pos)
		start_timer(pos, ON_TIME)
	end,
	on_timer = flicker,
})
register_lamp("lamp_ceiling_flicker_off", "Ceiling lamp (flickering, off)", 0, {
	tiles = lamp_tiles("st_interior_lamp_off_bottom.png"),
	drop = LIT,
	groups = {[GROUP] = 1, not_in_creative_inventory = 1},
	on_timer = flicker,
})

-- Schematics do not run on_construct, so make sure every flickering lamp has a timer
core.register_lbm({
	name = "st_interior:lamp_flicker_timer",
	nodenames = {LIT, DARK},
	run_at_every_load = true,
	action = function(pos)
		if not core.get_node_timer(pos):is_started() then
			start_timer(pos, ON_TIME)
		end
	end,
})
