-- Interior nodes tagged with a use kind (str_utils.constants.interact) call that kind's listeners on
-- right-click, so game logic hooks in without touching node definitions

local valid = {}
for _, kind in pairs(str_utils.constants.interact) do
	valid[kind] = true
end

local listeners = {}

local function check(kind)
	if not valid[kind] then
		error("str_interior: unknown use kind '" .. tostring(kind) .. "'", 3)
	end
end

-- fn(player_name, pos, node); pos is the clicked node, which can be any part of a multi-node set
function str_interior.register_on_use(kind, fn)
	check(kind)
	listeners[kind] = listeners[kind] or {}
	table.insert(listeners[kind], fn)
end

function str_interior.make_on_rightclick(kind)
	check(kind)
	return function(pos, node, clicker)
		if not (clicker and clicker:is_player()) then
			return
		end
		local player_name = clicker:get_player_name()
		for _, fn in ipairs(listeners[kind] or {}) do
			fn(player_name, pos, node)
		end
	end
end

-- Pointing at a tagged node on foot shows its prompt in the lower middle of the screen
local PROMPTS = {
	upgrade = "Upgrades",
	refuel = "Refuel",
	repair = "Repair",
	warehouse = "Storage",
	terminal = "Messages",
	sleep = "Sleep",
	drive = "Enter Vehicle",
}
local PROMPT_HUD = "str_interior:use_prompt"
local PROMPT_INTERVAL = 0.1
local DEFAULT_RANGE = 4

str_hud.register_text(PROMPT_HUD, {
	position = {x = 0.5, y = 0.8}, offset = {x = 0, y = 0}, size = 1.3, color = 0xFFFFFF,
	mode = "foot", background = {},
})

-- player name -> prompt currently set
local current = {}

local function pointed_kind(player)
	local props = player:get_properties()
	local eye = vector.offset(player:get_pos(), 0, props.eye_height, 0)
	local range = player:get_wielded_item():get_definition().range or DEFAULT_RANGE
	local target = vector.add(eye, vector.multiply(player:get_look_dir(), range))
	for pointed in core.raycast(eye, target, false, false) do
		if pointed.type == "node" then
			local def = core.registered_nodes[core.get_node(pointed.under).name]
			return def and def.use_kind
		end
	end
end

local elapsed = 0
core.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < PROMPT_INTERVAL then
		return
	end
	elapsed = 0
	for _, player in ipairs(core.get_connected_players()) do
		if str_mode.get(player) == "foot" then
			local kind = pointed_kind(player)
			local label = kind and PROMPTS[kind] or ""
			local name = player:get_player_name()
			if label ~= current[name] then
				current[name] = label
				str_hud.set_text(player, PROMPT_HUD, label)
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	current[player:get_player_name()] = nil
end)
