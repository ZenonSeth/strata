local cargo = {}

local META_KEY = "str_machine:cargo"

local items = {}
local cache = {}

-- def: {volume = ..., weight = ...} per unit
function cargo.register_item(name, def)
	items[name] = {volume = def.volume, weight = def.weight}
end

local function contents(player)
	local name = player:get_player_name()
	if not cache[name] then
		local meta = player:get_meta()
		local raw = meta:get_string(META_KEY)
		if raw == "" then
			meta:set_string(META_KEY, "{}")
			cache[name] = {}
		else
			local data = core.parse_json(raw)
			cache[name] = type(data) == "table" and data or {}
		end
	end
	return cache[name]
end

local listeners = {}

-- fn(player) runs after the hold contents change
function cargo.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

local function save(player)
	player:get_meta():set_string(META_KEY, core.write_json(contents(player)))
	for _, fn in ipairs(listeners) do
		fn(player)
	end
end

local function total(player, field)
	local sum = 0
	for name, count in pairs(contents(player)) do
		local def = items[name]
		if def then
			sum = sum + def[field] * count
		end
	end
	return sum
end

function cargo.volume(player)
	return total(player, "volume")
end

function cargo.weight(player)
	return total(player, "weight")
end

function cargo.get(player)
	return table.copy(contents(player))
end

-- Adds as many units as fit; returns how many were added
function cargo.add(player, name, count)
	local def = items[name]
	if not def then
		return 0
	end
	local free = str_machine.stats.get(player).cargo_capacity - cargo.volume(player)
	local fit = math.min(count, math.floor(free / def.volume + 1e-6))
	if fit <= 0 then
		return 0
	end
	local held = contents(player)
	held[name] = (held[name] or 0) + fit
	save(player)
	return fit
end

local PICKUP_TIME = 2
local PICKUP_COLOR = 0xA8E6B0
local popups = {}

-- Shows "+N name" above the bars; repeats of the same item within the window add up
function cargo.announce(player, name, count)
	local def = str_materials.items[name]
	if count <= 0 or not def then
		return
	end
	local pname = player:get_player_name()
	local popup = popups[pname]
	if popup and popup.name == name then
		popup.count = popup.count + count
		popup.job:cancel()
		player:hud_change(popup.id, "text", "+" .. popup.count .. " " .. def.description)
	else
		if popup then
			popup.job:cancel()
			player:hud_remove(popup.id)
		end
		popup = {name = name, count = count, id = player:hud_add({
			type = "text", position = {x = 0.5, y = 1}, offset = {x = 0, y = -145},
			text = "+" .. count .. " " .. def.description, style = 1, number = PICKUP_COLOR,
			alignment = {x = 0, y = 0}, size = {x = 1.5, y = 1.5}, z_index = 3,
		})}
		popups[pname] = popup
	end
	popup.job = core.after(PICKUP_TIME, function()
		local current = core.get_player_by_name(pname)
		if current then
			current:hud_remove(popup.id)
		end
		popups[pname] = nil
	end)
end

core.register_on_leaveplayer(function(player)
	local popup = popups[player:get_player_name()]
	if popup then
		popup.job:cancel()
		popups[player:get_player_name()] = nil
	end
end)

-- Removes up to count units; returns how many were removed
function cargo.remove(player, name, count)
	local held = contents(player)
	local removed = math.min(count, held[name] or 0)
	if removed <= 0 then
		return 0
	end
	held[name] = held[name] - removed
	if held[name] == 0 then
		held[name] = nil
	end
	save(player)
	return removed
end

function cargo.clear(player)
	cache[player:get_player_name()] = {}
	save(player)
end

function cargo.forget(player)
	cache[player:get_player_name()] = nil
end

-- A smaller hold cannot be equipped while the cargo would not fit in it
str_machine.stats.register_equip_check("cargo", function(player, level)
	local volume, capacity = cargo.volume(player), level.stats.cargo_capacity
	if volume > capacity + 1e-6 then
		return false, ("Hold has %g %s; this fits %g."):format(volume, str_utils.constants.volume_unit, capacity)
	end
	return true
end)

local BAR = "str_machine:cargo"
local FULL_COLOR = 0xFF4040

-- Spans the hull and fuel bars above it
str_hud.register_bar(BAR, {
	color = str_utils.constants.colors.cargo, width = 500, height = 20, size = 1.1, offset = {x = 0, y = -82},
	mode = "vehicle",
})

local function format_volume(value)
	return ("%g"):format(math.floor(value * 10 + 0.5) / 10)
end

function cargo.refresh(player)
	local volume, capacity = cargo.volume(player), str_machine.stats.get(player).cargo_capacity
	local label = format_volume(volume) .. "/" .. format_volume(capacity) .. " " .. str_utils.constants.volume_unit
	local full = capacity > 0 and volume >= capacity - 1e-6
	str_hud.set_bar(player, BAR, volume, capacity, {
		label = full and label .. " FULL" or label, text_color = full and FULL_COLOR or nil, bold = full,
	})
end

cargo.register_on_change(cargo.refresh)
str_machine.stats.register_on_change(cargo.refresh)

str_machine.cargo = cargo
