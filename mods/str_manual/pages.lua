local function lines(...)
	return table.concat({...}, "\n")
end

-- Hypertext keeps runs of spaces, so padding the mono key column lines up the descriptions
local KEY_COLUMN = 18
local function key(keys, text)
	return ("<style color=#6b1f14><mono><b>%s</b></mono></style>%s"):format(
		keys .. string.rep(" ", KEY_COLUMN - #keys), text)
end

str_manual.register_page("controls", "Controls", lines(
	"<b>Driving the machine</b>",
	key("Left / Right", "Drive left / right."),
	key("Up", "Fire the thrusters and climb. Let go and you fall."),
	key("Down", "Dig downwards."),
	key("Sneak", "Hover: brake your fall and hold in place."),
	key("Sneak + Up/Down", "Climb or sink slowly while hovering."),
	"Hovering uses fuel and does not work with an empty tank.",
	"",
	"<b>Using things</b>",
	key("E", "Use a pad or station you are next to (Aux1 on touch)."),
	"The prompt appears on screen when something is in reach.",
	"",
	"<b>Digging</b>",
	"Hold a direction against a node and the drill starts on it. Hold it until the node breaks; let go or turn away and the dig stops.",
	"Digging uses fuel, twice as fast as driving."
))

str_manual.register_page("upgrades", "Upgrades", lines(
	"<b>Upgrading</b>",
	"Every part of the machine can be upgraded: tank, hull, cargo hold, engine, thrusters and drill bit. Upgrades are made from materials you mine and store. Use the upgrade station in the shop to see what the next level of each part needs.",
	"",
	"<b>Checking your machine</b>",
	"The Equipment tab in your inventory shows the current level and stats of each part."
))

str_manual.register_page("fuel_hull", "Fuel & Hull", lines(
	"<b>Fuel</b>",
	"The machine burns fuel whenever it drives, climbs or digs. Digging burns the most. Hovering burns a little less than climbing. Standing still or falling is free. A bigger tank holds more. A faster engine moves you faster, but also uses fuel faster.",
	"",
	"<b>At zero fuel</b>",
	"You do not die. The drill stops working, and the machine crawls at about a tenth of its normal speed, sideways and upwards. You can still limp back to the shop.",
	"Refuel at the refuel station in the shop. If you cannot pay, the station will lend you half a tank and add it to your debt.",
	"",
	"<b>Hull</b>",
	"The hull is the machine's health. It is damaged by hard landings, falling rocks and hot liquids such as lava. Repair it at the repair station using materials from storage.",
	"",
	"<b>At zero hull</b>",
	"The machine is destroyed. <style color=#a82018>You lose everything in the cargo hold and all your upgrades</style>, and go back to the start with a stock hull and half a tank. Items in shop storage are safe."
))

str_manual.register_page("cargo", "Cargo", lines(
	"<b>Volume</b>",
	"The cargo hold is limited by volume, in cubic metres. Each material takes up a different amount of room: most ores take one unit each, bulky ones like quartz take more, and gems take the least, so a hold can carry a lot of them.",
	"",
	"<b>Weight</b>",
	"Each material is also a different density, so the same room can weigh very different amounts. Gems weigh almost nothing, coal and aluminum are light, and dense ores like gold and tungsten are heavy.",
	"Weight does not use up space in the hold, but a heavy load slows your thrusters. See the Thrusters page."
))

str_manual.register_page("thrusters", "Thrusters", lines(
	"<b>Climb speed</b>",
	"The fastest the machine can climb. A better thruster raises it.",
	"",
	"<b>Rated load</b>",
	"The cargo weight in T (tons). Weight affects how fast you accelerate, not your top speed.",
	"An empty hold climbs at full strength. At the rated load, acceleration falls to about a tenth of that.",
	"Above the rated load, an overloaded machine may not be able to fly up at all.",
	"",
	"<b>Matching</b>",
	"Each thruster is matched to the cargo hold of the same level: its rating is roughly the weight of that hold filled with gold. Dense ores can go over the rating, so pay attention to what you carry.",
	"",
	"<b>Digging up</b>",
	"Propellers cannot dig upwards: nodes above are solid walls to them. Jets and rockets can."
))

str_manual.register_page("drill", "Drill", lines(
	"<b>Max tier</b>",
	"Every node has a tier, and the harder the rock, the higher it is. The drill bit can only break nodes up to its own max tier. Anything harder is too tough for it, so you will need a better bit to go deeper.",
	"",
	"<b>Speed</b>",
	"A better bit also digs faster. How long a node takes depends on how hard it is and how fast your drill is, so tough rock takes longer than soft rock."
))

str_manual.register_page("demolition", "Demolition", lines(
	"<b>Explosives and lasers</b>",
	"Both can break nodes your drill bit is too weak for, up to their own tier. Make them in the Create Items tab of the upgrade station, then move them to your hotbar. Select one in the hotbar and press use (left click) while in the machine. Like everything in the hotbar, they are lost if the machine is destroyed.",
	"",
	"<b>Explosives</b>",
	"Each explosive is used up when it goes off. It blasts the nodes around the machine, and whatever they held is destroyed with them. Round charges clear a circle; line and shaped charges clear a row to each side. You can carry up to 50 of each kind.",
	"",
	"<b>Lasers</b>",
	"A laser needs its blueprint from the company shop, and three things to fire: the laser in your hotbar, a laser mounting point fitted in the hull, and a battery in your hotbar. Buying any laser blueprint lets you make the mounting point and the small battery.",
	"With a laser selected, a crosshair appears. Aim it at a node in your slice and click to fire. The beam runs from the machine towards that node, up to the laser's range, and breaks everything on the way. It stops at the first node too hard for it. Gems survive the beam and are left behind as a pile to collect; everything else it breaks is destroyed.",
	"Red, green and blue lasers reach further and break harder rock in that order, and the stronger ones take more energy per shot.",
	"",
	"<b>Batteries</b>",
	"Each shot takes energy from the first battery in your hotbar that has enough. The bar under a battery shows how much charge is left. A battery that is too low for a shot stays in the hotbar; carry a bigger one, or several. Recharge batteries at the refuel station for credits per MJ; the battery section shows while one is in your hotbar, and the > button picks the next one. Bigger batteries need their own blueprints."
))
