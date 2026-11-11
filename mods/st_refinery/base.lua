local FORMNAME = "st_refinery:main"
local WIDTH, HEIGHT = 15, 9
local MARGIN = 0.4
local LIST_W = 6.2
local PANEL_X = MARGIN + LIST_W + 0.4
local PANEL_W = WIDTH - PANEL_X - MARGIN
local TOP = st_gui.CONTENT_Y
local BUTTON_H, BUTTON_W, GAP = 0.9, 1.85, 0.1
local BATCH = 10
local BUFFER_KEY = "st_refinery:buffer"
local EPS = 1e-6
local SHORT_COLOR = "#d06a5a"

local esc = core.formspec_escape
local cargo, storage = st_machine.cargo, st_storage
local theme = st_gui.theme

-- Fuel materials, weakest first
local fuels = {}
for name, units in pairs(st_materials.fuel) do
	fuels[#fuels + 1] = {name = name, units = units}
end
table.sort(fuels, function(a, b)
	if a.units ~= b.units then
		return a.units < b.units
	end
	return a.name < b.name
end)

local selected_recipe, selected_fuel, messages = {}, {}, {}

local function desc(name)
	return st_materials.get(name).description
end

local function total(hold, store, name)
	return (hold[name] or 0) + (store[name] or 0)
end

-- Fuel units already drawn from a material but not yet burned: {fuel = name, units = n}
local function get_buffer(player)
	local raw = player:get_meta():get_string(BUFFER_KEY)
	local data = raw ~= "" and core.parse_json(raw)
	if type(data) == "table" and st_materials.fuel[data.fuel] and (tonumber(data.units) or 0) > EPS then
		return {fuel = data.fuel, units = tonumber(data.units)}
	end
	return {units = 0}
end

local function set_buffer(player, buffer)
	player:get_meta():set_string(BUFFER_KEY, core.write_json(buffer.units > EPS and buffer or {}))
end

local function known_recipes(player)
	local list = {}
	for _, recipe in ipairs(st_recipes.list) do
		if recipe.kind == "material" and st_recipes.has(player, recipe.name) then
			list[#list + 1] = recipe
		end
	end
	return list
end

-- Hold first, then storage
local function take(player, name, count)
	local removed = cargo.remove(player, name, count)
	if removed < count then
		storage.remove(player, name, count - removed)
	end
end

-- Makes one unit; returns true, or false and the reason. Nothing is used up unless it succeeds.
local function refine_once(player, recipe, fuel_name)
	local hold, store = cargo.get(player), storage.get(player)
	for input, amount in pairs(recipe.from) do
		if total(hold, store, input) < amount then
			return false, "Not enough " .. desc(input) .. "."
		end
	end
	local buffer = get_buffer(player)
	local per = st_materials.fuel[fuel_name]
	local draws = 0
	local missing = recipe.fuel_cost - buffer.units
	if missing > EPS then
		draws = math.ceil(missing / per - EPS)
		if total(hold, store, fuel_name) - (recipe.from[fuel_name] or 0) < draws then
			return false, "Not enough " .. desc(fuel_name) .. " for fuel."
		end
	end
	if cargo.add(player, recipe.name, 1) < 1 and storage.add(player, recipe.name, 1) < 1 then
		return false, "No room for the result."
	end
	for input, amount in pairs(recipe.from) do
		take(player, input, amount)
	end
	if draws > 0 then
		take(player, fuel_name, draws)
		buffer.fuel = fuel_name
	end
	buffer.units = buffer.units + draws * per - recipe.fuel_cost
	set_buffer(player, buffer)
	return true
end

-- Makes up to count units; returns the result line
local function refine(player, recipe, fuel_name, count)
	local made, reason = 0, nil
	while made < count do
		local ok
		ok, reason = refine_once(player, recipe, fuel_name)
		if not ok then
			break
		end
		made = made + 1
	end
	if made == 0 then
		return reason
	end
	return ("Made %d %s.%s"):format(made, recipe.description, reason and (" Stopped: " .. reason) or "")
end

local function recipe_list(player, list, hold, store)
	local rows, selected = {}, 0
	for i, recipe in ipairs(list) do
		-- Counts ingredients only, not fuel
		local can_make = math.huge
		for input, amount in pairs(recipe.from) do
			can_make = math.min(can_make, math.floor(total(hold, store, input) / amount + EPS))
		end
		rows[i] = {
			color = can_make > 0 and theme.text or theme.muted,
			cells = {recipe.description, tostring(total(hold, store, recipe.name)), tostring(can_make)},
		}
		if recipe.name == selected_recipe[player:get_player_name()] then
			selected = i
		end
	end
	return st_gui.list_table({
		x = MARGIN, y = TOP, w = LIST_W, h = HEIGHT - TOP - MARGIN, name = "recipes",
		columns = {
			{title = "Recipe", spec = "text,width=9,padding=0.3"},
			{title = "Have", spec = "text,width=3,padding=0.3,tooltip=Units in the hold and storage"},
			{title = "Can make", spec = "text,width=4,padding=0.3,tooltip=Units the ingredients allow (fuel not counted)"},
		},
		rows = rows, selected = selected,
	})
end

local function ingredient_table(recipe, hold, store)
	local names = {}
	for input in pairs(recipe.from) do
		names[#names + 1] = input
	end
	table.sort(names)
	local rows = {}
	for i, input in ipairs(names) do
		local need = recipe.from[input]
		rows[i] = {
			color = total(hold, store, input) >= need and theme.text or SHORT_COLOR,
			cells = {desc(input), tostring(need), tostring(hold[input] or 0), tostring(store[input] or 0)},
		}
	end
	return st_gui.list_table({
		x = PANEL_X, y = TOP + 1.2, w = PANEL_W, h = 3.2, name = "ingredients",
		columns = {
			{title = "Ingredient", spec = "text,width=9,padding=0.3"},
			{title = "Need", spec = "text,width=3,padding=0.3"},
			{title = "Hold", spec = "text,width=3,padding=0.3"},
			{title = "Storage", spec = "text,width=4,padding=0.3"},
		},
		rows = rows, selected = 0,
	})
end

local function fuel_dropdown(player, hold, store)
	local items, index = {}, 1
	local chosen = selected_fuel[player:get_player_name()] or fuels[1].name
	for i, fuel in ipairs(fuels) do
		items[i] = esc(("%s (%d)"):format(desc(fuel.name), total(hold, store, fuel.name)))
		if fuel.name == chosen then
			index = i
		end
	end
	return ("dropdown[%g,%g;%g,%g;fuel;%s;%d;true]"):format(
		PANEL_X, HEIGHT - MARGIN - BUTTON_H, PANEL_W - 2 * (BUTTON_W + GAP), BUTTON_H, table.concat(items, ","), index)
end

local function build(player)
	local name = player:get_player_name()
	local fs = {st_gui.header(WIDTH, HEIGHT, "Ore Refinery")}
	local list = known_recipes(player)
	if #list == 0 then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, TOP + 0.5,
			esc("You do not know any recipes yet. Buy them from the company contact."))
		return table.concat(fs)
	end
	local hold, store = cargo.get(player), storage.get(player)
	local recipe = st_recipes.get(selected_recipe[name] or "")
	if not recipe or not st_recipes.has(player, recipe.name) then
		recipe = list[1]
		selected_recipe[name] = recipe.name
	end
	local buffer = get_buffer(player)
	fs[#fs + 1] = recipe_list(player, list, hold, store)
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(PANEL_X, TOP + 0.3, esc(recipe.description))
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(PANEL_X, TOP + 0.8, esc(("Fuel cost: %g units"):format(recipe.fuel_cost)))
	fs[#fs + 1] = ingredient_table(recipe, hold, store)
	local y = TOP + 4.7
	if buffer.fuel then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(PANEL_X, y, esc(
			("Buffered: %s units of %s"):format(st_inventory.num(buffer.units), desc(buffer.fuel))))
	end
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(PANEL_X, y + 0.6, esc(messages[name] or ""))
	fs[#fs + 1] = ("label[%g,%g;Fuel:]"):format(PANEL_X, HEIGHT - MARGIN - BUTTON_H - 0.3)
	fs[#fs + 1] = fuel_dropdown(player, hold, store)
	local x = PANEL_X + PANEL_W - 2 * BUTTON_W - GAP
	fs[#fs + 1] = ("button[%g,%g;%g,%g;refine_one;Refine 1]"):format(x, HEIGHT - MARGIN - BUTTON_H, BUTTON_W, BUTTON_H)
	fs[#fs + 1] = ("button[%g,%g;%g,%g;refine_ten;Refine %d]"):format(
		x + BUTTON_W + GAP, HEIGHT - MARGIN - BUTTON_H, BUTTON_W, BUTTON_H, BATCH)
	return table.concat(fs)
end

function st_refinery.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local name = player:get_player_name()
	local fuel = fuels[tonumber(fields.fuel) or 0]
	if fuel then
		selected_fuel[name] = fuel.name
	end
	local recipe = st_recipes.get(selected_recipe[name] or "")
	if fields.refine_one or fields.refine_ten then
		if recipe and st_recipes.has(player, recipe.name) then
			messages[name] = refine(player, recipe, selected_fuel[name] or fuels[1].name, fields.refine_ten and BATCH or 1)
		end
	elseif fields.recipes then
		local event = core.explode_table_event(fields.recipes)
		if event.type ~= "CHG" and event.type ~= "DCL" then
			return
		end
		local picked = known_recipes(player)[event.row]
		selected_recipe[name], messages[name] = picked and picked.name, nil
	end
	st_refinery.show(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_recipe[name], selected_fuel[name], messages[name] = nil, nil, nil
end)
