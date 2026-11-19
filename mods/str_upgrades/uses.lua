-- What each material is for, worked out from the fuel, smelter, upgrade and workbench data so it cannot go stale
local uses

local function build()
	uses = {}
	for _, def in ipairs(str_materials.list) do
		uses[def.name] = {fuel = str_materials.fuel[def.name] ~= nil, smelts = {}, upgrades = false, crafts = false}
	end
	for _, def in ipairs(str_materials.list) do
		if def.kind == "smelted" then
			for input in pairs(def.from) do
				table.insert(uses[input].smelts, def.description)
			end
		end
	end
	for _, use in pairs(uses) do
		table.sort(use.smelts)
	end
	for _, category in ipairs(str_machine_data.upgrades) do
		for _, level in ipairs(category.levels) do
			for input in pairs(level.from or {}) do
				uses[input].upgrades = true
			end
		end
	end
	for _, craftable in ipairs(str_upgrades.craftables) do
		for input in pairs(craftable.from or {}) do
			uses[input].crafts = true
		end
	end
end

-- {fuel, smelts = sorted descriptions, upgrades, crafts} for a material name, or nil if it is not a material
function str_upgrades.material_uses(name)
	if not uses then
		build()
	end
	return uses[name]
end

function str_upgrades.has_uses(name)
	local use = str_upgrades.material_uses(name)
	return use ~= nil and (use.fuel or #use.smelts > 0 or use.upgrades or use.crafts)
end
