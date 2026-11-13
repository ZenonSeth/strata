-- Credits per unit = PRICE_BASE * PRICE_STEP ^ price_rank, rounded to 2 significant digits
local PRICE_BASE = 10
local PRICE_STEP = 1.3
-- A smelted material sells for this much times the price of its inputs
local REFINE_MARKUP = 1.5

local function round2(price)
	local unit = 1
	while price / unit >= 100 do
		unit = unit * 10
	end
	return math.floor(price / unit + 0.5) * unit
end

-- name -> {name, description, kind, volume, weight, price, ...}; list keeps the order raw, gems, smelted
str_materials.items = {}
str_materials.list = {}

local function add(def)
	assert(not str_materials.items[def.name], "str_materials: duplicate " .. def.name)
	str_materials.items[def.name] = def
	str_materials.list[#str_materials.list + 1] = def
end

for _, def in ipairs(dofile(str_materials.modpath .. "/ores.lua")) do
	def.price = round2(PRICE_BASE * PRICE_STEP ^ def.price_rank)
	add(def)
end

for _, def in ipairs(dofile(str_materials.modpath .. "/gems.lua")) do
	def.price = round2(PRICE_BASE * PRICE_STEP ^ def.price_rank)
	add(def)
end

for _, def in ipairs(dofile(str_materials.modpath .. "/relics.lua")) do
	add(def)
end

-- material name -> fuel units per unit burned in the smeltery
str_materials.fuel = dofile(str_materials.modpath .. "/fuels.lua")
for name in pairs(str_materials.fuel) do
	assert(str_materials.items[name], "str_materials: unknown fuel " .. name)
end

for _, def in ipairs(dofile(str_materials.modpath .. "/smelted.lua")) do
	assert(def.fuel_cost, "str_materials: no fuel_cost for " .. def.name)
	def.kind = "smelted"
	def.volume = def.volume or 1
	local weight, price = 0, 0
	for input, amount in pairs(def.from) do
		local item = assert(str_materials.items[input], "str_materials: unknown input " .. input)
		weight = weight + item.weight * amount
		price = price + item.price * amount
	end
	def.weight = def.weight or weight
	def.price = def.price or round2(price * REFINE_MARKUP)
	add(def)
end

local ICON_SIZE = 32
-- Ore textures are world-aligned sheets of this many cells per side
local ORE_SHEET = 8

local function has_file(mod, file)
	local path = core.get_modpath(mod)
	local f = path and io.open(path .. "/textures/" .. file, "rb")
	if f then
		f:close()
		return true
	end
	return false
end

-- Flat square in a colour from the name, until there is art
local function fallback_icon(name)
	local hue = 0
	for i = 1, #name do
		hue = (hue * 31 + name:byte(i)) % 360
	end
	local color = "#"
	for _, n in ipairs({5, 3, 1}) do
		local k = (n + hue / 60) % 6
		local c = 0.85 - 0.85 * 0.6 * math.max(0, math.min(k, 4 - k, 1))
		color = color .. string.format("%02x", math.floor(c * 255 + 0.5))
	end
	return "[fill:" .. ICON_SIZE .. "x" .. ICON_SIZE .. ":" .. color
end

-- Own art (textures/str_materials_<name>.png) wins; ores use the first cell of the rich ore sheet,
-- gems the node cell, anything else a placeholder
local function icon_for(def)
	local own = "str_materials_" .. def.name .. ".png"
	if has_file("str_materials", own) then
		return own
	end
	if def.kind == "ore" then
		local sheet = "str_nodes_ore_" .. def.name .. "_rich.png"
		if has_file("str_nodes", sheet) then
			return sheet .. "^[sheet:" .. ORE_SHEET .. "x" .. ORE_SHEET .. ":0,0"
		end
	elseif def.kind == "gem" then
		local cell = "str_nodes_gem_" .. def.name .. ".png"
		if has_file("str_nodes", cell) then
			return cell
		end
	end
	return fallback_icon(def.name)
end

for _, def in ipairs(str_materials.list) do
	def.icon = icon_for(def)
end

function str_materials.get(name)
	return str_materials.items[name]
end
