str_machine_data = {}
str_machine_data.modpath = core.get_modpath(core.get_current_modname())

-- Upgrade categories in tab order, see tanks.lua for the shape
str_machine_data.upgrades = {}
local by_id = {}

function str_machine_data.get_upgrade(id)
	return by_id[id]
end

-- Display text for a stat value; stat is a category's stat or extra entry
function str_machine_data.format_stat(stat, value)
	if stat.names then
		return stat.names[value]
	end
	value = value * (stat.scale or 1)
	if stat.format then
		return stat.format:format(value)
	end
	return ("%g%s"):format(value, stat.unit and (" " .. stat.unit) or "")
end

local function check(category)
	local id = category.id
	assert(type(id) == "string" and not by_id[id], "str_machine_data: bad or duplicate category id " .. tostring(id))
	assert(type(category.title) == "string", "str_machine_data: " .. id .. " needs a title")
	assert(#category.levels >= 1, "str_machine_data: " .. id .. " has no levels")
	assert(type(category.stat) == "table" and type(category.stat.label) == "string"
		and category.levels[1].stats[category.stat.key] ~= nil, "str_machine_data: " .. id .. " has a bad stat")
	for _, extra in ipairs(category.extra or {}) do
		assert(category.levels[1].stats[extra.key] ~= nil, "str_machine_data: " .. id .. " has a bad extra stat")
	end
	local names = {}
	for i, level in ipairs(category.levels) do
		local where = id .. " level " .. i
		assert(type(level.name) == "string" and not names[level.name], "str_machine_data: bad or duplicate name at " .. where)
		names[level.name] = true
		assert(type(level.stats) == "table" and next(level.stats), "str_machine_data: no stats at " .. where)
		for key in pairs(category.levels[1].stats) do
			assert(level.stats[key] ~= nil, "str_machine_data: " .. where .. " is missing stat " .. key)
		end
		assert(level.recipe_price == nil or (type(level.recipe_price) == "number" and level.recipe_price > 0),
			"str_machine_data: bad recipe_price at " .. where)
		assert(level.open == nil or type(level.open) == "boolean", "str_machine_data: bad open at " .. where)
		if i == 1 then
			assert(level.from == nil, "str_machine_data: " .. where .. " is the stock level and has no from")
		else
			assert(type(level.from) == "table" and next(level.from), "str_machine_data: no from at " .. where)
			for material, amount in pairs(level.from) do
				assert(type(material) == "string" and type(amount) == "number" and amount > 0,
					"str_machine_data: bad from at " .. where)
			end
		end
	end
end

for _, file in ipairs({"tanks", "hulls", "cargo", "thrusters", "drills", "engines", "lights"}) do
	local category = dofile(str_machine_data.modpath .. "/" .. file .. ".lua")
	check(category)
	by_id[category.id] = category
	table.insert(str_machine_data.upgrades, category)
end
