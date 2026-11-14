local res = str_player_resources

local KEY_PREFIX = "str_player_resources:"

-- Resource names and their starting values; kept in player meta, rounded to 2 decimals
local START = {credits = 0}

local listeners = {}

local function get(player, name)
	local raw = player:get_meta():get_string(KEY_PREFIX .. name)
	return tonumber(raw) or START[name]
end

local function set(player, name, value)
	value = math.max(0, math.floor(value * 100 + 0.5) / 100)
	player:get_meta():set_string(KEY_PREFIX .. name, ("%.2f"):format(value))
	for _, fn in ipairs(listeners) do
		fn(player, name, value)
	end
end

-- Takes amount only if the player has it; returns whether it did
local function spend(player, name, amount)
	if get(player, name) + 1e-6 < amount then
		return false
	end
	set(player, name, get(player, name) - amount)
	return true
end

function res.get_credits(player)
	return get(player, "credits")
end

function res.set_credits(player, value)
	set(player, "credits", value)
end

function res.add_credits(player, amount)
	set(player, "credits", get(player, "credits") + amount)
end

function res.spend_credits(player, amount)
	return spend(player, "credits", amount)
end

-- 252523 -> "252,523.00"
function res.format_credits(value)
	local whole, cents = ("%.2f"):format(value):match("^(%d+)(%.%d+)$")
	whole = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return whole .. cents
end

-- fn(player, name, value) runs after a resource changes
function res.register_on_change(fn)
	listeners[#listeners + 1] = fn
end


local CREDITS_HUD = "str_player_resources:credits"
str_hud.register_text(CREDITS_HUD, {
	position = {x = 1, y = 0}, offset = {x = -10, y = 22}, size = 1.3, color = 0xFFFFFF,
	align = "right", mono = true,
})

local function show_credits(player)
	str_hud.set_text(player, CREDITS_HUD, res.format_credits(res.get_credits(player)) .. " credits")
end

res.register_on_change(show_credits)
core.register_on_joinplayer(show_credits)

local GAIN_HUD = "str_player_resources:gain"
local GAIN_SECONDS = 5
str_hud.register_text(GAIN_HUD, {
	position = {x = 1, y = 0}, offset = {x = -10, y = 54}, size = 1.3, color = 0x55DD55,
	align = "right", mono = true,
})

local gain_token = {}

-- Shows a green "+amount" under the credits for a few seconds; a newer one replaces it
function res.show_gain(player, amount)
	local name = player:get_player_name()
	local token = (gain_token[name] or 0) + 1
	gain_token[name] = token
	str_hud.set_text(player, GAIN_HUD, "+" .. res.format_credits(amount))
	core.after(GAIN_SECONDS, function()
		local p = core.get_player_by_name(name)
		if p and gain_token[name] == token then
			str_hud.set_text(p, GAIN_HUD, " ")
		end
	end)
end

core.register_on_leaveplayer(function(player)
	gain_token[player:get_player_name()] = nil
end)

str_mail.register_on_read(function(name, mail)
	local player = core.get_player_by_name(name)
	if player and mail.credits then
		res.add_credits(player, mail.credits)
		res.show_gain(player, mail.credits)
	end
end)
