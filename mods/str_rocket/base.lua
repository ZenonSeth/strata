local storage = core.get_mod_storage()

-- The signal that unlocks both blueprint recipes
local UNLOCK_ID = "sig_16"

-- kind -> blueprint item, made in Create Items; a placed site keeps the player from making another
local BLUEPRINTS = {
	{kind = "site", item = "str_rocket:site_blueprint", description = "Rocket site blueprint",
		info = "Marks out a rocket site on level ground above the surface", image = "str_rocket_site_blueprint.png"},
	{kind = "support", item = "str_rocket:support_blueprint", description = "Launch workshop blueprint",
		info = "Marks out the launch workshop on level ground above the surface",
		image = "str_rocket_support_blueprint.png"},
}

local BLUEPRINT_FROM = {oak_planks = 1}

-- Far enough to point at the ground around the machine from the surface camera
local POINT_RANGE = 24

-- item -> kind, kind -> item
str_rocket.blueprint_kinds, str_rocket.blueprint_items = {}, {}
for _, def in ipairs(BLUEPRINTS) do
	str_rocket.blueprint_kinds[def.item] = def.kind
	str_rocket.blueprint_items[def.kind] = def.item
	core.register_craftitem(def.item, {
		description = def.description .. "\n" .. def.info
			.. "\nIn surface mode, point at the ground and left click\nPlacement is permanent, choose carefully",
		short_description = def.description,
		inventory_image = def.image,
		stack_max = 1,
		range = POINT_RANGE,
		on_use = function(itemstack, user)
			str_rocket.use_blueprint(itemstack, user)
		end,
		on_drop = function(itemstack) return itemstack end,
	})
	def.recipe = str_recipes.add_item_recipe({name = "rocket_" .. def.kind, description = def.description,
		from = BLUEPRINT_FROM, hidden = true})
end

str_rocket.blueprints = BLUEPRINTS

-- Per-player state in mod storage: {site = placed site, support = placed launch workshop, support_built = true}
local cache = {}

local function key(name)
	return "rocket:" .. name
end

local function data(name)
	if not cache[name] then
		local raw = storage:get_string(key(name))
		cache[name] = raw ~= "" and core.parse_json(raw) or {}
	end
	return cache[name]
end

function str_rocket.save(name)
	storage:set_string(key(name), core.write_json(data(name)))
end

str_rocket.data = data

local function holds(player, item)
	for listname in pairs(player:get_inventory():get_lists()) do
		if player:get_inventory():contains_item(listname, item) then
			return true
		end
	end
	return false
end

-- Whether the player holds this kind's blueprint or has placed its site, so another cannot be made
function str_rocket.blueprint_owned(player, kind)
	return data(player:get_player_name())[kind] ~= nil or holds(player, str_rocket.blueprint_items[kind])
end

-- Unlocks the Create Items recipes once the signal is received
local function unlock_recipes(player)
	if not str_transmissions.has_received(player:get_player_name(), UNLOCK_ID) then
		return
	end
	local unlocked = false
	for _, def in ipairs(BLUEPRINTS) do
		unlocked = str_recipes.unlock(player, def.recipe) or unlocked
	end
	if unlocked then
		str_utils.show_popup(player:get_player_name(), "Rocket blueprints unlocked in Create Items", 4)
	end
end

str_transmissions.register_on_receive(function(name, id)
	local player = id == UNLOCK_ID and core.get_player_by_name(name)
	if player then
		unlock_recipes(player)
	end
end)

-- Puts back any missing fence node of the player's placed sites
local function restore_sites(name)
	for _, def in ipairs(BLUEPRINTS) do
		local anchor = data(name)[def.kind]
		if anchor then
			core.load_area(vector.offset(anchor, -2, -1, -2), vector.offset(anchor, 2, 1, 2))
			local built = def.kind == "support" and data(name).support_built
			str_rocket.restore(def.kind, anchor, built and str_rocket.workshop_nodes or nil)
		end
	end
end

core.register_on_joinplayer(function(player)
	unlock_recipes(player)
	restore_sites(player:get_player_name())
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	cache[name] = nil
end)
