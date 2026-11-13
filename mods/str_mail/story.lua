-- Data only. Story mails by id: {from, subject, text}. Sent with str_mail.send_story, keyed by the id.
-- Text is shown in a monospace box; ASCII only. Placeholder wording, to be refined (see story.md).
return function(constants)
local TOTAL = constants.story.starting_debt

-- 1234567 -> "1,234,567"
local function commas(n)
	return (("%d"):format(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local ITEMS = {
	{"Digging Machine (financed)", 1200000},
	{"Machine \"Convenience Fee\"", 340000},
	{"Land Lease (day one)", 2500000},
	{"Air Access Fee (quarterly, up front)", 900000},
	{"Mandatory Orientation Letter", 150000},
	{"Shop Interior (\"lifestyle package\")", 1750000},
	{"Signup Bonus Clawback", 1000000},
	{"Processing of This Statement", 60000},
}

-- "Other" absorbs the rest, so the statement always adds up to the starting debt
local function statement_lines()
	local lines, rest = {}, TOTAL
	for _, item in ipairs(ITEMS) do
		rest = rest - item[2]
		lines[#lines + 1] = item
	end
	assert(rest >= 0, "str_mail: starting debt is below the listed line items")
	lines[#lines + 1] = {"Other", rest}
	local out = {}
	for i, item in ipairs(lines) do
		out[i] = ("  %-38s%10s"):format(item[1], commas(item[2]))
	end
	out[#out + 1] = "  " .. ("-"):rep(48)
	out[#out + 1] = ("  %-38s%10s"):format("TOTAL OWED", commas(TOTAL))
	return out
end

return {
	free_gift = {
		from = "Customer Delight Department, Excelsior Deep Yield Group",
		subject = "Your Free* gift is waiting!",
		text = table.concat({
			"Dear Valued Miner,",
			"",
			"As a thank-you for joining us, we are delighted to offer you a FREE* gift: a set of Dim Vehicle Lights, available now at the Company Shop!",
			"",
			"Why dig in the dark when you could dig in the slightly-less-dark? Dim Vehicle Lights light up the depths so you can see ore you would otherwise have bumped into.",
			"",
			"*Free of charge. Shipping and handling: 99.95 credits. Gift is not a gift. Offer valid while we say it is.",
		}, "\n"),
	},
	jim = {
		from = "Jim Harlow",
		subject = "You too, huh?",
		text = table.concat({
			"Hey friend,",
			"",
			"I see you got tricked by their promotion material too. Same here. I've been out on Strata a good while now, so here is some advice from one miner to another.",
			"",
			"- Don't sell all your coal. You'll want some for smelting your ore into better stuff, and that's what digger upgrades are built from.",
			"- Buy the lights from the Company Shop. They're not really free, whatever the company says, but you'll dig deeper when you can see where you're going.",
			"- Your first good upgrade should be a bigger cargo hold. The copper one carries a lot more than your stock hold does, and that's fewer trips back up to sell.",
			"",
			"Keep your head down and keep digging. Maybe we'll cross paths down there.",
			"",
			"Jim",
		}, "\n"),
	},
	welcome = {
		from = "Accounts Receivable, Excelsior Deep Yield Group",
		subject = "Welcome aboard! Your account summary (ACTION REQUIRED)",
		text = table.concat({
			"Congratulations on your new position as a Deep Yield Mining Execute on the planet Strata!",
			"",
			"Here is your Welcome Balance:",
			"",
			table.concat(statement_lines(), "\n"),
			"",
			"Please note that leaving the premises before the balance is cleared is a breach of Section 14(c).",
			"",
			"Good luck!",
		}, "\n"),
	},
}
end
