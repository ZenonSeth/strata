-- The table saw window: cuts timber into planks (into shop storage) and makes furniture (into the saw's own
-- output list, then moved to the hand hotbar by hand). Laid out like the Create Items tab of the upgrade station.
local FORMNAME = "str_furnish:table_saw"
local OUT_LIST, OUT_SLOTS = "str_furnish_saw", 8
local esc = core.formspec_escape

local WIDTH = 15
local MARGIN = 0.7
local GRID_NAME = "saw"
local GRID_Y, GRID_W, GRID_H, GRID_COLUMNS = str_gui.CONTENT_Y, 7.6, 6.9, 4
local INFO_X = MARGIN + GRID_W + 0.25
local INFO_W = WIDTH - MARGIN - INFO_X
local INFO_PAD = 0.25
local INFO_SIZE = 14
local OUT_LABEL_Y = GRID_Y + GRID_H + 0.2
local OUT_Y = OUT_LABEL_Y + 0.25
local HOTBAR_LABEL_Y = OUT_Y + 1.35
local HOTBAR_Y = HOTBAR_LABEL_Y + 0.25
local HEIGHT = HOTBAR_Y + 1.6
local BATCH = 10

str_audio.sfx.register("furnish_saw", {sound = "str_machine_dug_wood", gain = 0.5})

local CATEGORIES = {
	{id = "planks", title = "Planks", icon = "str_materials_oak_planks.png"},
	{id = "furniture", title = "Furniture", icon = "str_furnish_chair.png"},
}

-- {name, category, description, from, count, info, and material (to storage) or item (to the output list)}
local CRAFTS = {}
for _, mat in ipairs(str_materials.list) do
	if mat.kind == "sawn" then
		local inputs = {}
		for input in pairs(mat.from) do
			inputs[#inputs + 1] = str_materials.get(input).description:lower()
		end
		table.sort(inputs)
		CRAFTS[#CRAFTS + 1] = {name = mat.name, category = "planks", material = mat.name, image = mat.icon,
			description = mat.description, from = mat.from, count = mat.count,
			info = ("Cut from %s\nGoes to your shop storage"):format(table.concat(inputs, ", "))}
	end
end
for _, piece in ipairs(str_furnish.list) do
	if piece.station == "table_saw" then
		CRAFTS[#CRAFTS + 1] = {name = piece.name, category = "furniture", item = piece.item,
			description = piece.description, from = piece.from, count = 1, info = piece.info}
	end
end
str_furnish.saw_crafts = CRAFTS

local by_name, saw_items = {}, {}
for _, def in ipairs(CRAFTS) do
	by_name[def.name] = def
	if def.item then
		saw_items[def.item] = true
	end
end

-- player name -> pos of the clicked saw cell, selected craft name, grid scroll
local open_at, selected, grid_scroll = {}, {}, {}

-- Materials in shop storage plus the cargo hold
local function held_materials(player)
	local held = str_storage.get(player)
	for material, count in pairs(str_machine.cargo.get(player)) do
		held[material] = (held[material] or 0) + count
	end
	return held
end

local function sorted_materials(from)
	local names = {}
	for material in pairs(from) do
		names[#names + 1] = material
	end
	table.sort(names)
	return names
end

local function craft_count(def, held)
	local count
	for material, need in pairs(def.from) do
		local n = math.floor((held[material] or 0) / need)
		count = math.min(count or n, n)
	end
	return count or 0
end

-- From storage first, then the cargo hold
local function take_materials(player, from)
	for material, amount in pairs(from) do
		amount = amount - str_storage.remove(player, material, amount)
		if amount > 0 then
			str_machine.cargo.remove(player, material, amount)
		end
	end
end

-- Whether one more of def fits where it goes
local function has_room(player, def)
	if def.material then
		return str_storage.free_volume(player) >= str_materials.get(def.material).volume * def.count
	end
	return player:get_inventory():room_for_item(OUT_LIST, ItemStack(def.item .. " " .. def.count))
end

local function picked(player)
	return by_name[selected[player:get_player_name()] or ""] or CRAFTS[1]
end

local function label(def)
	return def.count > 1 and ("%s x%d"):format(def.description, def.count) or def.description
end

local function entries(player)
	local held = held_materials(player)
	local list = {}
	for _, cat in ipairs(CATEGORIES) do
		local header = false
		for _, def in ipairs(CRAFTS) do
			if def.category == cat.id then
				if not header then
					list[#list + 1] = {header = cat.title, icon = cat.icon}
					header = true
				end
				local count = craft_count(def, held)
				list[#list + 1] = {id = def.name, item = def.item, image = def.image, label = label(def),
					tooltip = label(def), dim = count == 0, badge = count > 0 and tostring(count) or nil,
					badge_color = str_gui.theme.equipped}
			end
		end
	end
	return list
end

local function needs_y(bottom, from)
	return bottom - str_gui.ACTION_H - 0.2 - (#sorted_materials(from) + 1) * str_gui.ICON_ROW_H
end

local function need_rows(x, y, w, from, held)
	local rows = {}
	for i, material in ipairs(sorted_materials(from)) do
		local need, have = from[material], held[material] or 0
		local def = str_materials.get(material)
		rows[i] = {icon = def.icon, text = ("%d %s"):format(need, def.description), right = tostring(have),
			right_color = have < need and str_gui.theme.danger or nil}
	end
	return str_gui.icon_rows(x, y, w, {"Needs", "Have"}, rows)
end

local function info(player, def)
	local theme = str_gui.theme
	local x, y, w = INFO_X + INFO_PAD, GRID_Y + INFO_PAD, INFO_W - 2 * INFO_PAD
	local bottom = GRID_Y + GRID_H - INFO_PAD
	local held = held_materials(player)
	local count = craft_count(def, held)
	local head_y = needs_y(bottom, def.from)
	local makes = def.count > 1 and ("\n<style color=%s>Makes %d</style>"):format(theme.muted, def.count) or ""
	local fs = {
		str_gui.info_title(x, y, w, def.item and {item = def.item} or {image = def.image},
			("<b><style size=18>%s</style></b>%s"):format(esc(def.description), makes)),
		("hypertext[%g,%g;%g,%g;;<global margin=0 color=%s size=%d>%s]"):format(x, y + str_gui.INFO_IMAGE + 0.15, w,
			head_y - y - str_gui.INFO_IMAGE - 0.25, theme.text, INFO_SIZE, esc(def.info)),
		need_rows(x, head_y, w, def.from, held),
	}
	local status, color, buttons = ("Can make: %d"):format(count), count > 0 and theme.text or theme.muted, nil
	if count > 0 and not has_room(player, def) then
		status, color = def.material and "Storage full" or "Made items full", theme.danger
	elseif count > 0 then
		buttons = {{"create", "Create"}}
		if def.material and count >= BATCH then
			table.insert(buttons, 1, {"create_batch", "x" .. BATCH, 1.2})
		end
	end
	fs[#fs + 1] = str_gui.action_row(x, bottom, w, status, color, buttons)
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local def = picked(player)
	local hotbar = str_hotbar.list(player, "foot")
	return table.concat({
		str_gui.header(WIDTH, HEIGHT, "Table saw"),
		str_furnish.pick_up_button(WIDTH),
		str_gui.tile_grid({
			x = MARGIN, y = GRID_Y, w = GRID_W, h = GRID_H, name = GRID_NAME, columns = GRID_COLUMNS,
			scroll = grid_scroll[name], entries = entries(player), selected = def.name,
		}),
		str_gui.input_bg(INFO_X, GRID_Y, INFO_W, GRID_H),
		info(player, def),
		("label[%g,%g;Made items]"):format(MARGIN, OUT_LABEL_Y),
		("list[current_player;%s;%g,%g;%d,1;0]"):format(OUT_LIST, MARGIN, OUT_Y, OUT_SLOTS),
		("label[%g,%g;Hand hotbar]"):format(MARGIN, HOTBAR_LABEL_Y),
		("list[current_player;%s;%g,%g;8,1;0]"):format(hotbar, MARGIN, HOTBAR_Y),
		("listring[current_player;%s]listring[current_player;%s]"):format(OUT_LIST, hotbar),
	})
end

local function show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

function str_furnish.show_saw(player, pos)
	open_at[player:get_player_name()] = vector.copy(pos)
	show(player)
end

-- Makes def up to times times while materials and room last; returns how many were made
local function make(player, def, times)
	local made = 0
	while made < times and craft_count(def, held_materials(player)) > 0 and has_room(player, def) do
		take_materials(player, def.from)
		if def.material then
			str_storage.add(player, def.material, def.count)
		else
			player:get_inventory():add_item(OUT_LIST, ItemStack(def.item .. " " .. def.count))
		end
		made = made + 1
	end
	return made
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME then
		return false
	end
	local name = player:get_player_name()
	local scroll = str_gui.tile_scroll(fields, GRID_NAME)
	if scroll then
		grid_scroll[name] = scroll
	end
	local pos = open_at[name]
	if fields.quit then
		open_at[name] = nil
		return true
	end
	if not (pos and str_furnish.owned_piece(pos, player)) then
		open_at[name] = nil
		core.close_formspec(name, FORMNAME)
		return true
	end
	local clicked = str_gui.tile_clicked(fields, GRID_NAME, entries(player))
	if fields.pick_up then
		if str_furnish.pick_up(pos, player) then
			open_at[name] = nil
			core.close_formspec(name, FORMNAME)
		end
		return true
	elseif clicked then
		selected[name] = clicked
	elseif fields.create or fields.create_batch then
		if make(player, picked(player), fields.create_batch and BATCH or 1) > 0 then
			str_audio.sfx.play("furnish_saw", {player = player})
		end
	else
		return true
	end
	show(player)
	return true
end)

core.register_allow_player_inventory_action(function(_, action, inv, info)
	if action == "move" and info.to_list == OUT_LIST then
		return saw_items[inv:get_stack(info.from_list, info.from_index):get_name()] and info.count or 0
	elseif action == "put" and info.listname == OUT_LIST then
		return saw_items[info.stack:get_name()] and info.stack:get_count() or 0
	end
end)

core.register_on_joinplayer(function(player)
	player:get_inventory():set_size(OUT_LIST, OUT_SLOTS)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	open_at[name], selected[name], grid_scroll[name] = nil, nil, nil
end)
