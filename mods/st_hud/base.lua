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
-- mode = only shown in this mode (default: always),
-- decimal = show one decimal in the label while max is 100 or less}
function st_hud.register_bar(id, def)
	elements[id] = {kind = "bar", def = def}
end

-- def: {position = {x, y} screen anchor, offset = {x, y} px, size = font multiplier,
-- color = 0xRRGGBB, mode = only shown in this mode (default: always),
-- align = "right" keeps the right edge fixed at the anchor (default: centered),
-- background = {color = ColorString, padding = {x, y} px} for a rectangle behind the text}
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

-- The engine cannot measure text, so the background size is estimated from the label length
local CHAR_WIDTH = 9
local LINE_HEIGHT = 20
local DEFAULT_BACKGROUND = "#00000099"
local DEFAULT_PADDING = {x = 10, y = 6}

local function background_scale(def, label)
	if label == "" then
		return {x = 0, y = 0}
	end
	local size = def.size or 1
	local padding = def.background.padding or DEFAULT_PADDING
	return {
		x = #label * CHAR_WIDTH * size + 2 * padding.x,
		y = LINE_HEIGHT * size + 2 * padding.y,
	}
end

local function create_text(player, def, label)
	local ids = {}
	local background
	local right = def.align == "right"
	local alignment = {x = right and -1 or 0, y = 0}
	local text_offset = def.offset
	if right and def.background then
		local padding = def.background.padding or DEFAULT_PADDING
		text_offset = {x = def.offset.x - padding.x, y = def.offset.y}
	end
	if def.background then
		background = player:hud_add({
			type = "image", position = def.position, offset = def.offset, z_index = Z_BG,
			text = "[fill:1x1:" .. (def.background.color or DEFAULT_BACKGROUND),
			scale = background_scale(def, label), alignment = alignment,
		})
		ids[1] = background
	end
	local hud = player:hud_add({
		type = "text", position = def.position, offset = text_offset,
		size = {x = def.size or 1, y = 0}, number = def.color or TEXT_COLOR,
		alignment = alignment, text = label, z_index = Z_TEXT,
	})
	ids[#ids + 1] = hud
	return {ids = ids, text = hud, background = background, label = label}
end

-- Rounds up, so the label only reads 0 when empty
local function bar_label(value, max, decimal)
	if not decimal or max > 100 then
		return math.ceil(value) .. "/" .. math.ceil(max)
	end
	return string.format("%.1f/%d", math.max(0, math.ceil(value * 10 - 1e-6)) / 10, math.ceil(max))
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
			if view.background then
				player:hud_change(view.background, "scale", background_scale(element.def, data.label))
			end
		end
		return
	end
	if not view then
		view = create_bar(player, element.def)
		shown[name][id] = view
	end
	-- The bar length is value / max; max only changes the label
	local fraction = data.max > 0 and math.max(0, math.min(data.value / data.max, 1)) or 0
	local label = bar_label(data.value, data.max, element.def.decimal)
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
