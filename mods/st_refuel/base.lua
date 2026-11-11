local FORMNAME = "st_refuel:main"
local WIDTH, HEIGHT = 12, 5.8
local MARGIN = 0.6
local BAR_Y, BAR_W, BAR_H, BAR_BORDER = 1.8, WIDTH - 2 * MARGIN, 0.9, 0.05
local BUTTON_W, BUTTON_GAP, BUTTON_H = 3.5, 0.15, 0.9
local BAR_COLOR, BAR_BG = st_utils.constants.colors.fuel, "#1b1c1e"
local BUY_LITRES = 5

local resources = st_player_resources
local format_credits = resources.format_credits
local price = st_utils.constants.fuel.price_per_litre

-- Last result line shown under the price, per player
local messages = {}

local function fill(color)
	return core.formspec_escape("[fill:8x8:" .. color)
end

local function bar(level, max)
	local fs = {
		("image[%g,%g;%g,%g;%s]"):format(MARGIN, BAR_Y, BAR_W, BAR_H, fill(BAR_BG)),
	}
	if level > 0 then
		local w = (BAR_W - 2 * BAR_BORDER) * math.min(level / max, 1)
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(
			MARGIN + BAR_BORDER, BAR_Y + BAR_BORDER, w, BAR_H - 2 * BAR_BORDER, fill(BAR_COLOR))
	end
	-- A flat button is the only element that centers text on top of the bar
	local clear = fill("#00000000")
	local text = max <= 100 and ("%.1f / %d L"):format(level, max) or ("%d / %d L"):format(level, max)
	fs[#fs + 1] = ("style[bar_text;border=false;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s]"):format(clear, clear, clear)
	fs[#fs + 1] = ("button[%g,%g;%g,%g;bar_text;%s]"):format(MARGIN, BAR_Y, BAR_W, BAR_H, core.formspec_escape(text))
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local level = st_machine.fuel.get(player)
	local max = st_machine.stats.get(player).max_fuel
	local fs = {
		st_gui.header(WIDTH, HEIGHT, "Refuel"),
		bar(level, max),
		("label[%g,%g;%s]"):format(MARGIN, BAR_Y + BAR_H + 0.5,
			core.formspec_escape(("Price: %g credits per litre     Credits: %s"):format(price, format_credits(resources.get_credits(player))))),
		("label[%g,%g;%s]"):format(MARGIN, BAR_Y + BAR_H + 1.1, core.formspec_escape(messages[name] or "")),
	}
	local labels = {
		{id = "buy_five", text = "Buy " .. BUY_LITRES .. " L"},
		{id = "fill_half", text = "Fill tank to 50%"},
		{id = "fill_full", text = "Fill tank to 100%"},
	}
	for i, button in ipairs(labels) do
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(
			MARGIN + (i - 1) * (BUTTON_W + BUTTON_GAP), HEIGHT - BUTTON_H - 0.4, BUTTON_W, BUTTON_H, button.id, button.text)
	end
	return table.concat(fs)
end

function st_refuel.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

-- Buys up to `litres`, or as much as the credits allow; returns the result line
local function buy(player, litres)
	if litres <= 0 then
		return nil
	end
	local credits = resources.get_credits(player)
	litres = math.min(litres, credits / price)
	if litres <= 0 then
		return "Not enough credits."
	end
	local cost = math.min(math.ceil(litres * price * 100 - 1e-6) / 100, credits)
	resources.spend_credits(player, cost)
	local added = st_machine.fuel.add(player, litres)
	return ("Bought %.1f L for %s credits."):format(added, format_credits(cost))
end

-- Fills the tank to a fraction of its size; does nothing if it is already above it
local function fill_to(player, fraction)
	local max = st_machine.stats.get(player).max_fuel
	local wanted = max * fraction - st_machine.fuel.get(player)
	if wanted <= 0 then
		return ("The tank is already at %d%% or more."):format(fraction * 100)
	end
	return buy(player, wanted)
end

function st_refuel.full_cost(player)
	local missing = st_machine.stats.get(player).max_fuel - st_machine.fuel.get(player)
	return math.max(math.ceil(missing * price * 100 - 1e-6) / 100, 0)
end

function st_refuel.fill_full(player)
	return fill_to(player, 1)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local name = player:get_player_name()
	if fields.buy_five then
		local max = st_machine.stats.get(player).max_fuel
		local space = max - st_machine.fuel.get(player)
		messages[name] = space <= 0 and "The tank is full." or buy(player, math.min(BUY_LITRES, space))
	elseif fields.fill_half then
		messages[name] = fill_to(player, 0.5)
	elseif fields.fill_full then
		messages[name] = fill_to(player, 1)
	else
		return
	end
	st_refuel.show(player)
end)

core.register_on_leaveplayer(function(player)
	messages[player:get_player_name()] = nil
end)

st_interior.register_on_use(st_utils.constants.interact.refuel, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		messages[player_name] = nil
		st_refuel.show(player)
	end
end)
