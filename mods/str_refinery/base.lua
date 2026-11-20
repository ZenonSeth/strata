local FORMNAME = "str_refinery:main"
local WIDTH, HEIGHT = 15, 11.85
local MARGIN = 0.4
local TOP = str_gui.CONTENT_Y
local BATCH = 10
local BATCH_FUEL = 0.8
local BUFFER_KEY = "str_refinery:buffer"
local EPS = 1e-6
local MADE_COLOR = "#b4e8a8"

-- Tile grid on the left, detail panel on the right (as in the company shop)
local GRID_NAME = "recipes"
local GRID_Y, GRID_W, GRID_COLUMNS, NAME_LINES = TOP, 8.2, 4, 2
local GRID_H = HEIGHT - 1 - GRID_Y
local INFO_X = MARGIN + GRID_W + 0.25
local INFO_W = WIDTH - MARGIN - INFO_X
local INFO_PAD = 0.25
local MESSAGE_H = 0.8
local FUEL_TILE_H, FUEL_ICON, FUEL_GAP = 0.9, 0.55, 0.12

local esc = core.formspec_escape
local num = str_inventory.num
local DIM = "#141517a0"
local CLEAR = esc("[fill:1x1:#00000000")
local HOVER = esc("[fill:1x1:#ffffff14")
local cargo, storage = str_machine.cargo, str_storage
local theme = str_gui.theme

-- Fuel materials, weakest first
local fuels = {}
for name, units in pairs(str_materials.fuel) do
	fuels[#fuels + 1] = {name = name, units = units}
end
table.sort(fuels, function(a, b)
	if a.units ~= b.units then
		return a.units < b.units
	end
	return a.name < b.name
end)

local selected_recipe, selected_fuel, messages, grid_scroll = {}, {}, {}, {}

-- Engine picks one of str_refinery_craft.N.ogg at random
str_audio.sfx.register("refinery_craft", {sound = "str_refinery_craft"})

local function desc(name)
	return str_materials.get(name).description
end

local function total(hold, store, name)
	return (hold[name] or 0) + (store[name] or 0)
end

-- Units the ingredients allow (fuel not counted)
local function can_make_count(recipe, hold, store)
	local count = math.huge
	for input, amount in pairs(recipe.from) do
		count = math.min(count, math.floor(total(hold, store, input) / amount + EPS))
	end
	return count
end

-- Fuel units already drawn from a material but not yet burned: {fuel = name, units = n}
local function get_buffer(player)
	local raw = player:get_meta():get_string(BUFFER_KEY)
	local data = raw ~= "" and core.parse_json(raw)
	if type(data) == "table" and str_materials.fuel[data.fuel] and (tonumber(data.units) or 0) > EPS then
		return {fuel = data.fuel, units = tonumber(data.units)}
	end
	return {units = 0}
end

local function set_buffer(player, buffer)
	player:get_meta():set_string(BUFFER_KEY, core.write_json(buffer.units > EPS and buffer or {}))
end

local function known_recipes(player)
	local list = {}
	for _, recipe in ipairs(str_recipes.list) do
		if recipe.kind == "material" and str_recipes.has(player, recipe.name) then
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
local function refine_once(player, recipe, fuel_name, fuel_mult)
	local hold, store = cargo.get(player), storage.get(player)
	for input, amount in pairs(recipe.from) do
		if total(hold, store, input) < amount then
			return false, "Not enough " .. desc(input) .. "."
		end
	end
	local buffer = get_buffer(player)
	local per = str_materials.fuel[fuel_name]
	local draws = 0
	local cost = recipe.fuel_cost * fuel_mult
	local missing = cost - buffer.units
	if missing > EPS then
		draws = math.ceil(missing / per - EPS)
		if total(hold, store, fuel_name) - (recipe.from[fuel_name] or 0) < draws then
			return false, "Not enough " .. desc(fuel_name) .. " for fuel."
		end
	end
	if storage.add(player, recipe.name, 1) < 1 then
		return false, "No room in storage for the result."
	end
	for input, amount in pairs(recipe.from) do
		take(player, input, amount)
	end
	if draws > 0 then
		take(player, fuel_name, draws)
		buffer.fuel = fuel_name
	end
	buffer.units = buffer.units + draws * per - cost
	set_buffer(player, buffer)
	return true
end

-- Whether a full batch can be made, so the batch fuel discount is earned
local function can_batch(player, recipe, fuel_name)
	local hold, store = cargo.get(player), storage.get(player)
	for input, amount in pairs(recipe.from) do
		if total(hold, store, input) < amount * BATCH then
			return false
		end
	end
	local missing = recipe.fuel_cost * BATCH_FUEL * BATCH - get_buffer(player).units
	local draws = missing > EPS and math.ceil(missing / str_materials.fuel[fuel_name] - EPS) or 0
	if total(hold, store, fuel_name) - (recipe.from[fuel_name] or 0) * BATCH < draws then
		return false
	end
	return storage.free_volume(player) + EPS >= BATCH * str_materials.get(recipe.name).volume
end

-- Makes up to count units; returns the result line
local function refine(player, recipe, fuel_name, count, fuel_mult)
	local made, reason = 0, nil
	while made < count do
		local ok
		ok, reason = refine_once(player, recipe, fuel_name, fuel_mult)
		if not ok then
			break
		end
		made = made + 1
	end
	if made == 0 then
		return reason
	end
	str_audio.sfx.play("refinery_craft", {player = player})
	return ("Made %d %s.%s"):format(made, recipe.description, reason and (" Stopped: " .. reason) or "")
end

local function recipe_entries(list, hold, store)
	local entries = {}
	for i, recipe in ipairs(list) do
		local have, can_make = total(hold, store, recipe.name), can_make_count(recipe, hold, store)
		entries[i] = {
			id = recipe.name, image = str_materials.get(recipe.name).icon, label = recipe.description,
			tooltip = recipe.description, badge = num(have), dim = can_make == 0,
			status = "Can make " .. num(can_make), status_color = can_make == 0 and theme.muted or nil,
		}
	end
	return entries
end

local function info_line(x, y, w, label, value)
	return str_gui.info_text(x, y, w, str_gui.ICON_ROW_H,
		("<style color=%s>%s:</style> %s"):format(theme.muted, esc(label), esc(value)))
end

-- Needs/Have rows with the hold and storage split in a tooltip; returns the formspec and its bottom
local function ingredient_rows(x, y, w, recipe, hold, store)
	local names = {}
	for input in pairs(recipe.from) do
		names[#names + 1] = input
	end
	table.sort(names, function(a, b) return desc(a) < desc(b) end)
	local rows, tips = {}, {}
	local row_h = str_gui.ICON_ROW_H
	for i, input in ipairs(names) do
		local need, have = recipe.from[input], total(hold, store, input)
		rows[i] = {icon = str_materials.get(input).icon, text = ("%d %s"):format(need, desc(input)), right = num(have),
			right_color = have < need and theme.danger or nil}
		tips[i] = ("tooltip[%g,%g;%g,%g;%s]"):format(x, y + i * row_h, w, row_h,
			esc(("Hold: %s, Storage: %s"):format(num(hold[input] or 0), num(store[input] or 0))))
	end
	return str_gui.icon_rows(x, y, w, {"Needs", "Have"}, rows) .. table.concat(tips), y + (#names + 1) * row_h
end

-- The Fuel header with the buffered fuel on its right, then one toggle tile per fuel
local function fuel_tiles(player, x, y, w, hold, store)
	local buffer = get_buffer(player)
	local fs = {str_gui.info_text(x, y, w, str_gui.ICON_ROW_H, "Fuel", theme.muted)}
	if buffer.fuel then
		fs[#fs + 1] = str_gui.info_text(x, y, w, str_gui.ICON_ROW_H, esc(("Buffered: %s %s"):format(
			str_inventory.num(buffer.units), desc(buffer.fuel))), theme.muted, "right")
	end
	local chosen = selected_fuel[player:get_player_name()] or fuels[1].name
	local tile_y = y + str_gui.ICON_ROW_H + 0.05
	local tile_w = (w - (#fuels - 1) * FUEL_GAP) / #fuels
	local names = {}
	for i, fuel in ipairs(fuels) do
		local tile_x = x + (i - 1) * (tile_w + FUEL_GAP)
		local icon_x, icon_y = tile_x + 0.12, tile_y + (FUEL_TILE_H - FUEL_ICON) / 2
		local count = total(hold, store, fuel.name)
		local btn = "fuel_" .. i
		names[i] = btn
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s;1]"):format(tile_x, tile_y, tile_w, FUEL_TILE_H,
			fuel.name == chosen and "str_gui_slot_hover.png" or "str_gui_slot.png")
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(icon_x, icon_y, FUEL_ICON, FUEL_ICON,
			esc(str_materials.get(fuel.name).icon))
		if count == 0 then
			fs[#fs + 1] = ("box[%g,%g;%g,%g;%s]"):format(icon_x, icon_y, FUEL_ICON, FUEL_ICON, DIM)
		end
		local text_x = icon_x + FUEL_ICON + 0.12
		fs[#fs + 1] = str_gui.info_text(text_x, tile_y + 0.05, tile_x + tile_w - text_x - 0.05, (FUEL_TILE_H - 0.1) / 2,
			esc(desc(fuel.name)), count == 0 and theme.muted or nil)
		fs[#fs + 1] = str_gui.info_text(text_x, tile_y + FUEL_TILE_H / 2, tile_x + tile_w - text_x - 0.05,
			(FUEL_TILE_H - 0.1) / 2, "<b>" .. num(count) .. "</b>", count == 0 and theme.muted or nil)
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;]tooltip[%s;%s]"):format(tile_x, tile_y, tile_w, FUEL_TILE_H, btn, btn,
			esc(("%s: %g fuel unit%s each"):format(desc(fuel.name), fuel.units, fuel.units == 1 and "" or "s")))
	end
	local list = table.concat(names, ",")
	table.insert(fs, 1, ("style[%s;border=false;bgimg=%s;bgimg_middle=0;padding=0]style[%s;bgimg=%s]"):format(
		list, CLEAR, list:gsub(",", ":hovered,") .. ":hovered", HOVER))
	return table.concat(fs)
end

-- The detail panel: image, name, counts, the ingredients, the fuel picker, the last result and the Refine buttons
local function recipe_info(player, recipe, hold, store)
	local name = player:get_player_name()
	local x, y, w = INFO_X + INFO_PAD, GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = GRID_Y + GRID_H - INFO_PAD
	local row_h = str_gui.ICON_ROW_H
	local fs = {
		str_gui.info_title(x, y, w, {image = str_materials.get(recipe.name).icon},
			("<b><style size=18>%s</style></b>\n<style color=%s>Smelting recipe</style>"):format(
			esc(recipe.description), theme.muted)),
	}
	local top = y + str_gui.INFO_IMAGE + 0.25
	fs[#fs + 1] = info_line(x, top, w, "Have", num(total(hold, store, recipe.name)))
	fs[#fs + 1] = info_line(x, top + row_h, w, "Can make", num(can_make_count(recipe, hold, store)))
	fs[#fs + 1] = info_line(x, top + 2 * row_h, w, "Fuel cost",
		("%g unit%s each"):format(recipe.fuel_cost, recipe.fuel_cost == 1 and "" or "s"))
	fs[#fs + 1] = ingredient_rows(x, top + 3 * row_h + 0.3, w, recipe, hold, store)

	local buttons_y = bottom - str_gui.ACTION_H
	local message_y = buttons_y - 0.1 - MESSAGE_H
	local message = messages[name]
	if message then
		local made = message:sub(1, 5) == "Made "
		fs[#fs + 1] = str_gui.info_text(x, message_y, w, MESSAGE_H, esc(message), made and MADE_COLOR or theme.danger)
	end
	fs[#fs + 1] = fuel_tiles(player, x, message_y - 0.15 - FUEL_TILE_H - 0.05 - row_h, w, hold, store)
	local button_w = (w - 0.1) / 2
	fs[#fs + 1] = str_gui.action_row(x, bottom, w, nil, nil,
		{{"refine_one", "Refine 1", button_w}, {"refine_ten", ("Refine %d"):format(BATCH), button_w}})
	fs[#fs + 1] = ("tooltip[refine_ten;%s]"):format(esc(("Refining %d at once burns only %g%% of the fuel."):format(
		BATCH, math.floor(BATCH_FUEL * 100 + 0.5))))
	return table.concat(fs)
end

-- Known recipes and the selected one (the first if the selection is not known)
local function current_recipe(player)
	local name = player:get_player_name()
	local list = known_recipes(player)
	for _, recipe in ipairs(list) do
		if recipe.name == selected_recipe[name] then
			return list, recipe
		end
	end
	selected_recipe[name] = list[1] and list[1].name
	return list, list[1]
end

local function build(player)
	local name = player:get_player_name()
	local fs = {str_gui.header(WIDTH, HEIGHT, "Ore Refinery")}
	local list, recipe = current_recipe(player)
	if not recipe then
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, TOP + 0.5,
			esc("You do not know any recipes yet. Buy them from the company shop."))
		return table.concat(fs)
	end
	local hold, store = cargo.get(player), storage.get(player)
	fs[#fs + 1] = str_gui.tile_grid({
		x = MARGIN, y = GRID_Y, w = GRID_W, h = GRID_H, name = GRID_NAME, columns = GRID_COLUMNS,
		name_lines = NAME_LINES, scroll = grid_scroll[name], entries = recipe_entries(list, hold, store),
		selected = recipe.name,
	})
	fs[#fs + 1] = str_gui.input_bg(INFO_X, GRID_Y, INFO_W, GRID_H)
	fs[#fs + 1] = recipe_info(player, recipe, hold, store)
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, HEIGHT - 0.45,
		esc("Refined items go straight to your mechanic shop storage."))
	return table.concat(fs)
end

function str_refinery.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return
	end
	local name = player:get_player_name()
	local scroll = str_gui.tile_scroll(fields, GRID_NAME)
	if scroll then
		grid_scroll[name] = scroll
	end
	if fields.quit then
		return
	end
	for i, fuel in ipairs(fuels) do
		if fields["fuel_" .. i] then
			selected_fuel[name] = fuel.name
		end
	end
	local list, recipe = current_recipe(player)
	local clicked = str_gui.tile_clicked(fields, GRID_NAME, recipe_entries(list, cargo.get(player), storage.get(player)))
	if clicked and clicked ~= selected_recipe[name] then
		selected_recipe[name], messages[name] = clicked, nil
	elseif recipe and (fields.refine_one or fields.refine_ten) then
		local fuel_name = selected_fuel[name] or fuels[1].name
		local batch = fields.refine_ten and can_batch(player, recipe, fuel_name)
		messages[name] = refine(player, recipe, fuel_name, fields.refine_ten and BATCH or 1, batch and BATCH_FUEL or 1)
	end
	str_refinery.show(player)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	selected_recipe[name], selected_fuel[name], messages[name], grid_scroll[name] = nil, nil, nil, nil
end)
