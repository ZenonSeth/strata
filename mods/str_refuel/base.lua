local FORMNAME = "str_refuel:main"
local WIDTH, HEIGHT = 12, 5.8
local MARGIN = 0.6
local BAR_Y, BAR_W, BAR_H, BAR_BORDER = 1.8, WIDTH - 2 * MARGIN, 0.9, 0.05
local BUTTON_W, BUTTON_GAP, BUTTON_H = 3.5, 0.15, 0.9
local BAR_COLOR, BAR_BG = str_utils.constants.colors.fuel, "#1b1c1e"
-- Fill texture pixels per formspec unit; keeps the stripes the same shape at any fill level
local BAR_PX = 25
local BUY_LITRES = 5
-- Battery section below the fuel buttons, shown while a battery is in the hotbar
local CHARGE_Y, CHARGE_EXTRA = HEIGHT - 0.1, 1.9
local SLOT_W, CYCLE_W, CHARGE_LABEL_W, CHARGE_BUTTON_W = 0.9, 0.4, 1.4, 2.4
local CHARGE_BUTTONS = {
	{id = "charge_step", text = "+5%"},
	{id = "charge_half", text = "to 50%"},
	{id = "charge_full", text = "to 100%"},
}

local resources = str_player_resources
local format_credits = resources.format_credits
local price = str_utils.constants.fuel.price_per_litre
local charge_price = str_utils.constants.recharge_price_per_mj
local format_energy = str_lasers.format_energy
local muted = str_gui.theme.muted

-- Last result line shown under the price, per player
local messages = {}
-- Hotbar index of the battery shown in the charge section, per player
local battery_slot = {}

-- The shown battery's hotbar index, or nil when the hotbar has none
local function current_slot(player)
	local slots = str_lasers.battery_slots(player)
	local want = battery_slot[player:get_player_name()]
	for _, i in ipairs(slots) do
		if i == want then
			return i, slots
		end
	end
	return slots[1], slots
end

local function fill(color)
	return core.formspec_escape("[fill:8x8:" .. color)
end

local function bar(level, max)
	local fs = {
		("image[%g,%g;%g,%g;%s]"):format(MARGIN, BAR_Y, BAR_W, BAR_H, fill(BAR_BG)),
	}
	if level > 0 then
		local px = math.max(1, math.floor((BAR_W - 2 * BAR_BORDER) * BAR_PX * math.min(level / max, 1) + 0.5))
		local h = BAR_H - 2 * BAR_BORDER
		fs[#fs + 1] = ("image[%g,%g;%g,%g;%s]"):format(MARGIN + BAR_BORDER, BAR_Y + BAR_BORDER, px / BAR_PX, h,
			core.formspec_escape(str_utils.bar_fill(BAR_COLOR, px, math.floor(h * BAR_PX + 0.5))))
	end
	-- A flat button is the only element that centers text on top of the bar
	local clear = fill("#00000000")
	local text = max <= 100 and ("%.1f / %d L"):format(level, max) or ("%d / %d L"):format(level, max)
	fs[#fs + 1] = ("style[bar_text;border=false;bgimg=%s;bgimg_hovered=%s;bgimg_pressed=%s]"):format(clear, clear, clear)
	fs[#fs + 1] = ("button[%g,%g;%g,%g;bar_text;%s]"):format(MARGIN, BAR_Y, BAR_W, BAR_H, core.formspec_escape(text))
	return table.concat(fs)
end

-- Empty tank and no credits: digging is off, so there is no way to earn fuel money
local function stranded(player)
	return str_machine.fuel.is_empty(player) and resources.get_credits(player) <= 0
end

local function charge_section(player, slot, slots)
	local stack = player:get_inventory():get_stack("main", slot)
	local fs = {
		("image[%g,%g;%g,%g;%s]"):format(MARGIN, CHARGE_Y, SLOT_W, SLOT_W, fill(BAR_BG)),
		("item_image[%g,%g;%g,%g;%s 1 %d]"):format(MARGIN, CHARGE_Y, SLOT_W, SLOT_W, stack:get_name(), stack:get_wear()),
		"style_type[label;valign=center]",
		("label[%g,%g;%g,%g;%s]"):format(MARGIN + SLOT_W + CYCLE_W + 0.3, CHARGE_Y, CHARGE_LABEL_W, BUTTON_H,
			core.formspec_escape(core.colorize(muted, "Charge:"))),
		"style_type[label;valign=top]",
		("label[%g,%g;%s]"):format(MARGIN, CHARGE_Y + BUTTON_H + 0.45, core.formspec_escape(
			("%s %s / %s     %s %g %s"):format(core.colorize(muted, stack:get_short_description() .. ":"),
				format_energy(str_lasers.get_charge(stack)), format_energy(str_lasers.capacity(stack)),
				core.colorize(muted, "Price:"), charge_price, core.colorize(muted, "credits per MJ")))),
	}
	if #slots > 1 then
		fs[#fs + 1] = ("button[%g,%g;%g,%g;charge_next;>]"):format(MARGIN + SLOT_W + 0.05, CHARGE_Y, CYCLE_W, SLOT_W)
	end
	local x = WIDTH - MARGIN - #CHARGE_BUTTONS * CHARGE_BUTTON_W - (#CHARGE_BUTTONS - 1) * BUTTON_GAP
	for i, button in ipairs(CHARGE_BUTTONS) do
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(
			x + (i - 1) * (CHARGE_BUTTON_W + BUTTON_GAP), CHARGE_Y, CHARGE_BUTTON_W, BUTTON_H, button.id, button.text)
	end
	return table.concat(fs)
end

local function build(player)
	local name = player:get_player_name()
	local level = str_machine.fuel.get(player)
	local max = str_machine.stats.get(player).max_fuel
	local slot, slots = current_slot(player)
	local fs = {
		str_gui.header(WIDTH, slot and HEIGHT + CHARGE_EXTRA or HEIGHT, "Refuel"),
		bar(level, max),
		("label[%g,%g;%s]"):format(MARGIN, BAR_Y + BAR_H + 0.5,
			core.formspec_escape(("%s %g %s     %s %s"):format(core.colorize(muted, "Price:"), price,
				core.colorize(muted, "credits per litre"), core.colorize(muted, "Credits:"),
				format_credits(resources.get_credits(player))))),
		("label[%g,%g;%s]"):format(MARGIN, BAR_Y + BAR_H + 1.1, core.formspec_escape(messages[name] or "")),
	}
	local labels = {
		{id = "buy_five", text = "Buy " .. BUY_LITRES .. " L"},
		{id = "fill_half", text = "Fill tank to 50%"},
		{id = "fill_full", text = "Fill tank to 100%"},
	}
	if stranded(player) then
		labels = {{id = "free_half", text = "Refuel 50% with credit"}}
	end
	for i, button in ipairs(labels) do
		fs[#fs + 1] = ("button[%g,%g;%g,%g;%s;%s]"):format(
			MARGIN + (i - 1) * (BUTTON_W + BUTTON_GAP), HEIGHT - BUTTON_H - 0.4, BUTTON_W, BUTTON_H, button.id, button.text)
	end
	if slot then
		fs[#fs + 1] = charge_section(player, slot, slots)
	end
	return table.concat(fs)
end

function str_refuel.show(player)
	core.show_formspec(player:get_player_name(), FORMNAME, build(player))
end

str_audio.sfx.register("refuel", {sound = "str_refuel_fill", gain = 0.5})
str_audio.sfx.register("charge", {sound = "str_refuel_charge"})

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
	local added = str_machine.fuel.add(player, litres)
	return ("Bought %.1f L for %s credits."):format(added, format_credits(cost))
end

-- Fills the tank to a fraction of its size; does nothing if it is already above it
local function fill_to(player, fraction)
	local max = str_machine.stats.get(player).max_fuel
	local wanted = max * fraction - str_machine.fuel.get(player)
	if wanted <= 0 then
		return ("The tank is already at %d%% or more."):format(fraction * 100)
	end
	return buy(player, wanted)
end

-- Charges the battery in a hotbar slot up to target_kj, or as far as the credits go; returns the result line
local function charge_to(player, slot, target_kj, full_text)
	local inv = player:get_inventory()
	local stack = inv:get_stack("main", slot)
	local have = str_lasers.get_charge(stack)
	local wanted = math.min(target_kj, str_lasers.capacity(stack)) - have
	if wanted <= 1e-6 then
		return full_text
	end
	local credits = resources.get_credits(player)
	local kj = math.min(wanted, credits / charge_price * 1000)
	if kj <= 1e-6 then
		return "Not enough credits."
	end
	local cost = math.min(math.ceil(kj / 1000 * charge_price * 100 - 1e-6) / 100, credits)
	resources.spend_credits(player, cost)
	str_lasers.set_charge(stack, have + kj)
	inv:set_stack("main", slot, stack)
	str_audio.sfx.play("charge", {player = player})
	return ("Charged %s for %s credits."):format(format_energy(kj), format_credits(cost))
end

local function handle_charge(player, fields)
	local slot, slots = current_slot(player)
	if not slot then
		return nil
	end
	local name = player:get_player_name()
	if fields.charge_next then
		for n, i in ipairs(slots) do
			if i == slot then
				battery_slot[name] = slots[n % #slots + 1]
			end
		end
		return messages[name]
	end
	local cap = str_lasers.capacity(player:get_inventory():get_stack("main", slot))
	if fields.charge_step then
		local have = str_lasers.get_charge(player:get_inventory():get_stack("main", slot))
		return charge_to(player, slot, have + cap * 0.05, "The battery is full.")
	elseif fields.charge_half then
		return charge_to(player, slot, cap * 0.5, "The battery is already at 50% or more.")
	end
	return charge_to(player, slot, cap, "The battery is full.")
end

function str_refuel.full_cost(player)
	local missing = str_machine.stats.get(player).max_fuel - str_machine.fuel.get(player)
	return math.max(math.ceil(missing * price * 100 - 1e-6) / 100, 0)
end

function str_refuel.fill_full(player)
	local before = str_machine.fuel.get(player)
	local result = fill_to(player, 1)
	if str_machine.fuel.get(player) > before then
		str_audio.sfx.play("refuel", {player = player})
	end
	return result
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORMNAME or fields.quit then
		return
	end
	local name = player:get_player_name()
	local before = str_machine.fuel.get(player)
	if fields.buy_five then
		local max = str_machine.stats.get(player).max_fuel
		local space = max - str_machine.fuel.get(player)
		messages[name] = space <= 0 and "The tank is full." or buy(player, math.min(BUY_LITRES, space))
	elseif fields.fill_half then
		messages[name] = fill_to(player, 0.5)
	elseif fields.free_half then
		if stranded(player) then
			local litres = str_machine.fuel.add(player, str_machine.stats.get(player).max_fuel / 2)
			local cost = math.ceil(litres * price * 100 - 1e-6) / 100
			str_story.add_debt(player, cost)
			messages[name] = ("Refueled %.1f L on credit. Debt +%s."):format(litres, format_credits(cost))
		end
	elseif fields.fill_full then
		messages[name] = fill_to(player, 1)
	elseif fields.charge_next or fields.charge_step or fields.charge_half or fields.charge_full then
		messages[name] = handle_charge(player, fields)
	else
		return
	end
	if str_machine.fuel.get(player) > before then
		str_audio.sfx.play("refuel", {player = player})
	end
	str_refuel.show(player)
end)

core.register_on_leaveplayer(function(player)
	messages[player:get_player_name()] = nil
	battery_slot[player:get_player_name()] = nil
end)

str_interior.register_on_use(str_utils.constants.interact.refuel, function(player_name)
	local player = core.get_player_by_name(player_name)
	if player then
		messages[player_name] = nil
		str_refuel.show(player)
	end
end)
