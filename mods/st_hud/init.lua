st_hud = {}

local BORDER = 2
local BG_COLOR = "#202020"
local TEXT_COLOR = 0xFFFFFF
local Z_BG, Z_FILL, Z_TEXT = 0, 1, 2

-- id -> {kind = "bar" or "text", def = ...}
local elements = {}
-- player name -> id -> latest pushed data, kept whatever the mode is
local model = {}
-- player name -> id -> {ids = {hud ids}, fill/text = hud id, fraction = n, label = s}
local shown = {}

-- def: {color = ColorString, width, height (px), offset = {x, y} from bottom center,
-- mode = only shown in this mode (default: always)}
function st_hud.register_bar(id, def)
	elements[id] = {kind = "bar", def = def}
end

-- def: {position = {x, y} screen anchor, offset = {x, y} px, size = font multiplier,
-- color = 0xRRGGBB, mode = only shown in this mode (default: always)}
function st_hud.register_text(id, def)
	elements[id] = {kind = "text", def = def}
end

local function visible(player, element)
	local mode = element.def.mode
	return mode == nil or mode == st_mode.get(player)
end

local function create_bar(player, def)
	local anchor = {x = 0.5, y = 1}
	local w, h, off = def.width, def.height, def.offset
	local bg = player:hud_add({
		type = "image", position = anchor, offset = off, z_index = Z_BG,
		text = "[fill:" .. (w + 2 * BORDER) .. "x" .. (h + 2 * BORDER) .. ":" .. BG_COLOR,
		scale = {x = 1, y = 1}, alignment = {x = 0, y = 0},
	})
	local fill = player:hud_add({
		type = "image", position = anchor, z_index = Z_FILL,
		offset = {x = off.x - w / 2, y = off.y},
		text = "[fill:" .. w .. "x" .. h .. ":" .. def.color,
		scale = {x = 0, y = 1}, alignment = {x = 1, y = 0},
	})
	local text = player:hud_add({
		type = "text", position = anchor, offset = off, z_index = Z_TEXT,
		text = "", number = TEXT_COLOR, alignment = {x = 0, y = 0},
	})
	return {ids = {bg, fill, text}, fill = fill, text = text}
end

local function create_text(player, def, label)
	local hud = player:hud_add({
		type = "text", position = def.position, offset = def.offset,
		size = {x = def.size or 1, y = 0}, number = def.color or TEXT_COLOR,
		alignment = {x = 0, y = 0}, text = label, z_index = Z_TEXT,
	})
	return {ids = {hud}, text = hud, label = label}
end

-- Brings the player's screen in line with the stored data
local function render(player, id)
	local element = elements[id]
	local name = player:get_player_name()
	local data = model[name] and model[name][id]
	if not data or not visible(player, element) then
		return
	end
	shown[name] = shown[name] or {}
	local view = shown[name][id]
	if element.kind == "text" then
		if not view then
			shown[name][id] = create_text(player, element.def, data.label)
		elseif data.label ~= view.label then
			view.label = data.label
			player:hud_change(view.text, "text", data.label)
		end
		return
	end
	if not view then
		view = create_bar(player, element.def)
		shown[name][id] = view
	end
	-- The bar length is value / max; max only changes the label
	local fraction = data.max > 0 and math.max(0, math.min(data.value / data.max, 1)) or 0
	local label = math.ceil(data.value) .. "/" .. math.ceil(data.max)
	if fraction ~= view.fraction then
		view.fraction = fraction
		player:hud_change(view.fill, "scale", {x = fraction, y = 1})
	end
	if label ~= view.label then
		view.label = label
		player:hud_change(view.text, "text", label)
	end
end

local function hide(player, id)
	local name = player:get_player_name()
	local view = shown[name] and shown[name][id]
	if not view then
		return
	end
	for _, hud_id in ipairs(view.ids) do
		player:hud_remove(hud_id)
	end
	shown[name][id] = nil
end

local function store(player, id, kind, data)
	local element = elements[id]
	if not element or element.kind ~= kind then
		return
	end
	local name = player:get_player_name()
	model[name] = model[name] or {}
	model[name][id] = data
	render(player, id)
end

function st_hud.set_bar(player, id, value, max)
	store(player, id, "bar", {value = value, max = max})
end

function st_hud.set_text(player, id, label)
	store(player, id, "text", {label = label})
end

st_mode.register_on_change(function(player)
	for id, element in pairs(elements) do
		if visible(player, element) then
			render(player, id)
		else
			hide(player, id)
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	model[name] = nil
	shown[name] = nil
end)
