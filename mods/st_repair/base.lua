local FORMNAME = "st_repair:main"
local WIDTH, HEIGHT = 12, 6.8
local MARGIN = 0.6
local BAR_Y, BAR_W, BAR_H, BAR_BORDER = 2.3, WIDTH - 2 * MARGIN, 0.9, 0.05
local BUTTON_W, BUTTON_GAP, BUTTON_H = 3.5, 0.15, 0.9
local BAR_COLOR, BAR_BG = st_utils.constants.colors.hull, "#1b1c1e"

local stats = st_machine.stats
local hull = st_machine.hull
local resources = st_player_resources
local format_credits = resources.format_credits
local price_per_hp = st_utils.constants.repair_price_per_hp
-- A stage of the stock hull (no materials) is this fraction of its hit points
local STOCK_STAGE = 0.1

-- Last result line shown under the costs, per player
local messages = {}

local function fill(color)
	return core.formspec_escape("[fill:8x8:" .. color)
end

local function bar(level, max)
	local fs = {("image[%g,%g;%g,%g;%s]"):format(MARGIN, BAR_Y, BAR_W, BAR_H, fill(BAR_BG))}
	if level > 0 then
		local w = (BAR_W - 2 * BAR_BORDER) * math.min(level / max, 1)
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(
			MARGIN + BAR_BORDER, BAR_Y + BAR_BORDER, w, BAR_H - 2 * BAR_BORDER, fill(BAR_COLOR))
	end
	local clear = fill("#00000000")
	local text = ("%d / %d HP"):format(math.ceil(level), max)
	fs[#fs + 1] = ("style[bar_text;border=false;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s]"):format(clear, clear, clear)
	fs[#fs + 1] = ("button[%g,%g;%g,%g;bar_text;%s]"):format(MARGIN, BAR_Y, BAR_W, BAR_H, core.formspec_escape(text))
	return table.concat(fs)
end

-- The materials a repair of this fraction of the hull takes, rounded up per material
local function repair_cost(level, fraction)
	local cost = {}
	for material, amount in pairs(level.from or {}) do
		cost[material] = math.ceil(amount * fraction - 1e-6)
	end
	return cost
end

local function sorted(cost)
	local names = {}
	for material in pairs(cost) do
		names[#names + 1] = material
	end
	table.sort(names)
	return names
end

local function cost_text(cost, stored)
	local parts = {}
	for _, material in ipairs(sorted(cost)) do
		local text = ("%d %s"):format(cost[material], st_materials.get(material).description)
		parts[#parts + 1] = stored and ("%s (have %d)"):format(text, stored[material] or 0) or text
	end
	return table.concat(parts, ", ")
end

local function affordable(step, stored, credits)
	for material, amount in pairs(step.cost) do
		if (stored[material] or 0) < amount then
			return false
		end
	end
	return step.credits <= credits
end

-- "5 Copper plate (have 3)" or "100 credits (have 80)"
local function step_text(step, stored, credits)
	if step.credits > 0 then
		return ("%s credits%s"):format(format_credits(step.credits),
			credits and (" (have %s)"):format(format_credits(credits)) or "")
	end
	return cost_text(step.cost, stored)
end

-- The equipped hull and what a full or a one-stage repair would be. A built hull is paid in materials
-- and a stage is 1/N of the hull, N being the largest build amount (one unit of that material); the
-- stock hull is paid in credits and a stage is STOCK_STAGE of it
local function plan(player)
	local level = stats.get_level(player, "hull")
	local max = stats.get(player).max_hull
	local missing = max - hull.get(player)
	local p = {level = level, max = max, missing = missing}
	if missing <= 1e-6 then
		return p
	end
	p.full = {fraction = missing / max, hp = missing}
	p.full.cost = repair_cost(level, p.full.fraction)
	p.full.credits = level.from and 0 or math.ceil(missing * price_per_hp - 1e-6)
	if not level.from then
		local hp = math.min(STOCK_STAGE * max, missing)
		p.stage = {fraction = hp / max, hp = hp, cost = {}, credits = math.ceil(hp * price_per_hp - 1e-6)}
	else
		local biggest = 0
		for _, amount in pairs(level.from) do
			biggest = math.max(biggest, amount)
		end
		local fraction = math.min(1 / biggest, p.full.fraction)
		p.stage = {fraction = fraction, hp = fraction * max, cost = repair_cost(level, fraction), credits = 0}
	end
	return p
end

local function build(player)
	local name = player:get_player_name()
	local p = plan(player)
	local stored = st_storage.get(player)
	local credits = resources.get_credits(player)
	local fs = {
		st_gui.header(WIDTH, HEIGHT, "Repair"),
		("label[%g,%g;%s]"):format(MARGIN, 1.75, core.formspec_escape(p.level.description)),
		bar(hull.get(player), p.max),
	}
	local y = BAR_Y + BAR_H + 0.5
	local lines = {}
	if not p.full then
		lines[1] = "The hull does not need repairs."
	else
		lines[1] = ("Repair all: %s"):format(step_text(p.full, stored, credits))
		if p.stage then
			lines[2] = ("One stage: %s, restores %.1f HP"):format(step_text(p.stage), p.stage.hp)
		end
	end
	for i, line in ipairs(lines) do
		fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, y + (i - 1) * 0.55, core.formspec_escape(line))
	end
	fs[#fs + 1] = ("style_type[label;textcolor=%s]"):format(st_gui.theme.muted)
	fs[#fs + 1] = ("label[%g,%g;%s]"):format(MARGIN, y + #lines * 0.55, core.formspec_escape(messages[name] or ""))
	fs[#fs + 1] = ("style_type[label;textcolor=%s]"):format(st_gui.theme.text)
	local x = MARGIN
	for _, button in ipairs({{"repair_stage", "Repair 1 stage", p.stage}, {"repair_all", "Repair all", p.full}}) do
		local step = button[3]
		if step and affordable(step, stored, credits) then
			fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(x, HEIGHT - BUTTON_H - 0.4, BUTTON_W, BUTTON_H,
				button[1], button[2])
			x = x + BUTTON_W + BUTTON_GAP
		end
	end
	return table.concat(fs)
end

function st_repair.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

-- Takes the materials and restores the hull; returns the result line
local function repair(player, step)
	if not step then
		return "Nothing to repair."
	elseif not affordable(step, st_storage.get(player), resources.get_credits(player)) then
		return step.credits > 0 and "Not enough credits." or "Not enough materials."
	end
	for material, amount in pairs(step.cost) do
		st_storage.remove(player, material, amount)
	end
	if step.credits > 0 then
		resources.spend_credits(player, step.credits)
	end
	local restored = hull.add(player, step.hp)
	local used = step_text(step)
	return ("Repaired %.1f HP %s %s."):format(restored, step.credits > 0 and "for" or "using", used)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local p = plan(player)
	local name = player:get_player_name()
	if fields.repair_stage then
		messages[name] = repair(player, p.stage)
	elseif fields.repair_all then
		messages[name] = repair(player, p.full)
	else
		return
	end
	st_repair.show(player)
end)

core.register_on_leaveplayer(function(player)
	messages[player:get_player_name()] = nil
end)

st_interior.register_on_use(st_utils.constants.interact.repair, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		messages[player_name] = nil
		st_repair.show(player)
	end
end)
