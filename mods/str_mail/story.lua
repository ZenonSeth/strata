-- Data only. Story mails by id: {from, subject, text, credits (optional attachment)}. Sent with str_mail.send_story, keyed by the id.
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
	jim_death = {
		from = "Jim Harlow",
		subject = "Rough landing",
		credits = 2000,
		text = table.concat({
			"Hey friend,",
			"",
			"Heard you lost your digger. It happens to all of us, so don't take it too hard.",
			"",
			"Next time, watch your speed down there. Most crashes I've seen are a miner going faster than the machine can brake.",
			"",
			"And don't forget to upgrade your thrusters along with your cargo hold. A heavy hold on stock thrusters is how you end up in a hole.",
			"",
			"I'm attaching 2000 credits to help you get back on your feet.",
			"",
			"Jim",
		}, "\n"),
	},
	jim_gas = {
		from = "Jim Harlow",
		subject = "Watch out for gas",
		text = table.concat({
			"Hey friend,",
			"",
			"Looks like you're getting down there. Word of warning: the deeper you go, the more the rock holds pockets of natural gas.",
			"",
			"You can't see them coming. Your drill opens one up and it goes off right in your face, takes a chunk out of your hull and blows the rock around you apart. The further down you dig, the more often it happens and the harder it hits.",
			"",
			"Keep your hull patched up before you head deep, and take some repair kits with you just in case.",
			"",
			"Jim",
		}, "\n"),
	},
	jim_tools = {
		from = "Jim Harlow",
		subject = "Tools of the trade",
		text = table.concat({
			"Hey friend,",
			"",
			"A whole kilometre down already? Not bad. Your drill won't carry you forever, so here are a few tools worth knowing about. You make them all in the Create Items tab of your upgrade station, then put them in your hotbar.",
			"",
			"- Scanner: point it at the rock ahead and it tells you what's in there and whether your drill can take it. Saves a lot of wasted digging.",
			"- Explosives: for rock your drill is too weak for. They blow it apart, ore and all, so don't set them off next to anything you want to keep.",
			"- Lasers: same job, with reach. You'll need a blueprint from the Company Shop, a mounting point in your hull and a charged battery. Gems come through the beam in one piece.",
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
	corp_signal_1 = {
		from = "Operational Compliance, Excelsior Deep Yield Group",
		subject = "Notice: Unauthorized Outbound Transmission",
		text = table.concat({
			"Dear Miner,",
			"",
			"A routine review of your digging machine's logs shows that your unit sent an outbound transmission while below the surface. Our records indicate this was a reply to subsurface acoustic noise.",
			"",
			"Please be reminded that Company communication equipment is provided for operational purposes only (Section 9(b)). Subsurface noise is a known and harmless property of the local rock and does not require a response.",
			"",
			"We strongly encourage you to keep your attention on your primary objective: the timely repayment of your outstanding balance.",
			"",
			"This notice has been added to your file.",
		}, "\n"),
	},
	corp_signal_2 = {
		from = "Employee Wellbeing Office, Excelsior Deep Yield Group",
		subject = "Second Notice: Outbound Transmission and Wellbeing Review",
		text = table.concat({
			"Dear Miner,",
			"",
			"Our systems have detected a second outbound transmission from your digging machine, again addressed to subsurface noise.",
			"",
			"Our psychological assessment team has reviewed the logs. In their professional opinion, extended isolation at depth may be affecting your judgement. \"Talking to rocks\" is listed as an early warning sign in the Deep Yield Wellbeing Handbook (page 212).",
			"",
			"Do not repeat this behaviour. A further transmission will see you classed as a risk to Company operations, with the consequences set out in your contract.",
			"",
			"Remember: a productive miner is a happy miner.",
		}, "\n"),
	},
	corp_signal_3 = {
		from = "Employee Wellbeing Office, Excelsior Deep Yield Group",
		subject = "FINAL NOTICE: Departure Hold",
		text = table.concat({
			"Dear Miner,",
			"",
			"Despite two prior notices, your digging machine has sent a third outbound transmission to subsurface noise.",
			"",
			"You are now classed as a potential risk to Company operations. With immediate effect, a Departure Hold has been placed on your account: your departure from Strata is suspended pending a full psychological evaluation by a Company-approved assessor.",
			"",
			"The Departure Hold does not affect your outstanding balance, which remains due in full. Repayments are still gratefully accepted.",
			"",
			"You will be notified when an assessor becomes available.",
		}, "\n"),
	},
}
end
