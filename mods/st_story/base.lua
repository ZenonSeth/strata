local KEY_DEBT = "st_story:debt"
local KEY_ENDING_DEBT = "st_story:ending_debt_found"

-- Whole cents; unset meta means the player has not touched the debt yet
function st_story.get_debt(player)
	local raw = player:get_meta():get_string(KEY_DEBT)
	return tonumber(raw) or st_utils.constants.story.starting_debt
end

local function set_debt(player, value)
	value = math.max(0, math.floor(value * 100 + 0.5) / 100)
	player:get_meta():set_string(KEY_DEBT, ("%.2f"):format(value))
end

function st_story.add_debt(player, amount)
	set_debt(player, st_story.get_debt(player) + amount)
end

-- Pays at most the debt owed; returns how much was taken
function st_story.pay_debt(player, amount)
	local paid = math.min(amount, st_story.get_debt(player))
	set_debt(player, st_story.get_debt(player) - paid)
	return paid
end

-- Credits from free text: digits with an optional decimal part (spaces and commas ignored); nil if bad
function st_story.parse_amount(text)
	text = (text or ""):gsub("[%s,]", "")
	if #text == 0 or #text > 14 or not (text:match("^%d+%.?%d*$") or text:match("^%.%d+$")) then
		return nil
	end
	local value = math.floor(tonumber(text) * 100 + 0.5) / 100
	return value > 0 and value or nil
end

function st_story.get_ending_debt_found(player)
	return player:get_meta():get_string(KEY_ENDING_DEBT) == "1"
end

function st_story.set_ending_debt_found(player)
	player:get_meta():set_string(KEY_ENDING_DEBT, "1")
end
