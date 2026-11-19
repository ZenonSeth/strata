local storage = core.get_mod_storage()

-- Remove or comment out this block to allow multiplayer
-- core.register_on_prejoinplayer(function()
-- 	if not core.is_singleplayer() then
-- 		return "Strata is singleplayer only: multiplayer has not been tested.\n"
-- 			.. "To try it anyway, comment out the singleplayer check in mods/str_start/base.lua."
-- 	end
-- end)

local grid = str_utils.constants.interior
local SCHEMATIC = core.get_modpath("str_start") .. "/schems/shop_home.mts"
local DONE_KEY = "str_start:started"
-- JSON {x, y, z (relative to the interior origin), yaw, pitch}: where a player who quit on foot stood
local POS_KEY = "str_start:interior_pos"
-- Player meta of the old permanent slots (0.5 to 0.7), cleared on join
local OLD_KEYS = {"str_start:slot", "str_start:interior_layout", "str_start:interior_version"}
local BED_FOOT = "str_interior:home_bed_foot"
local DIGGER = "str_interior:digger_display"
local SPAWN_MARKER = "str_interior:shop_floor_spawn"
-- Seconds before the display digger's model appears on first spawn
local DIGGER_SPAWN_DELAY = 1
-- Feet this far above the bed foot node's centre (its top face), so the drop onto the blanket is small
local FEET_ABOVE_BED = 0.5

-- The old permanent slot counter and legacy release flag
storage:set_string("next_slot", "")
storage:set_string("legacy_interiors_released", "")

-- Session slots, all free at server start: player name -> slot, slot -> player name
local slot_of, owner_of = {}, {}
-- Player names whose interior copy has been placed this session
local placed = {}
-- Player name -> token of their current session, so callbacks from an earlier session are ignored
local session_of, next_session = {}, 0
local FULL_TEXT = "The server is full: every workshop is in use."

local function slot_origin(slot)
	return vector.new(grid.origin.x + slot * grid.spacing, grid.origin.y, grid.origin.z)
end

local function free_slot()
	for slot = 0, grid.slots - 1 do
		if not owner_of[slot] then
			return slot
		end
	end
end

local function claim_slot(name)
	local slot = slot_of[name] or free_slot()
	if slot and not slot_of[name] then
		slot_of[name], owner_of[slot] = slot, name
		next_session = next_session + 1
		session_of[name] = next_session
	end
	return slot
end

local function release_slot(name)
	local slot = slot_of[name]
	if slot then
		owner_of[slot] = nil
	end
	slot_of[name], placed[name], session_of[name] = nil, nil, nil
end

-- Lowest corner of the player's interior this session, nil if they hold no slot
function str_start.get_origin(player)
	local slot = slot_of[player:get_player_name()]
	return slot and slot_origin(slot)
end

local function blocked(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	return not def or def.walkable
end

-- Whether the node at pos fills its whole cube for collision (unknown nodes count as full)
local function full_cube(pos)
	local def = core.registered_nodes[core.get_node(pos).name]
	if not def then
		return true
	end
	if not def.walkable then
		return false
	end
	local box = def.collision_box or (def.drawtype == "nodebox" and def.node_box)
	return not box or box.type == "regular"
end

-- Whether rel (relative to the origin) lies within an interior of size, to the outer node faces
local function in_box(rel, size)
	return rel.x >= -0.5 and rel.y >= -0.5 and rel.z >= -0.5
		and rel.x <= size.x - 0.5 and rel.y <= size.y - 0.5 and rel.z <= size.z - 0.5
end

-- Put the player on top of the node at node_pos (feet up_by above its centre), looking along its front,
-- or the opposite way with `behind`
local function stand_on(player, node_pos, up_by, behind)
	player:set_pos(vector.offset(node_pos, 0, up_by, 0))
	local yaw = core.dir_to_yaw(str_interior.facedir_front[core.get_node(node_pos).param2 % 4])
	player:set_look_horizontal(behind and yaw + math.pi or yaw)
	player:set_look_vertical(0)
end

local function place_player(player, origin, last)
	local foot = core.find_nodes_in_area(origin, last, BED_FOOT)[1]
	if foot then
		if blocked(vector.offset(foot, 0, 1, 0)) or blocked(vector.offset(foot, 0, 2, 0)) then
			core.log("warning", "str_start: no headroom above the bed foot at " .. core.pos_to_string(foot))
		end
		stand_on(player, foot, FEET_ABOVE_BED)
		return
	end
	core.log("error", "str_start: no " .. BED_FOOT .. " in the interior, using the shop spawn marker")
	local marker = core.find_nodes_in_area(origin, last, SPAWN_MARKER)[1]
	if marker then
		stand_on(player, marker, FEET_ABOVE_BED, true)
	else
		player:set_pos(vector.offset(origin, 1, 1, 1))
		player:set_look_vertical(0)
	end
end

-- Stands the player at the shop spawn marker, facing in (on the bed if there is none)
local function place_at_entrance(player, origin, last)
	local marker = core.find_nodes_in_area(origin, last, SPAWN_MARKER)[1]
	if marker then
		stand_on(player, marker, FEET_ABOVE_BED, true)
	else
		place_player(player, origin, last)
	end
end

-- Size of the interior schematic, read once; nil if it cannot be read
local interior_size
local function get_interior_size()
	if not interior_size then
		local schematic = core.read_schematic(SCHEMATIC, {write_yslice_prob = "none"})
		interior_size = schematic and schematic.size
	end
	return interior_size
end

-- Puts the player on their bed (the shop spawn marker if the interior has none)
function str_start.place_on_bed(player)
	local origin, size = str_start.get_origin(player), get_interior_size()
	if origin and size then
		place_player(player, origin, vector.offset(vector.add(origin, size), -1, -1, -1))
	end
end

-- Loads the interior's blocks, then calls on_done(player), with nil if the player left meanwhile
local function emerge_interior(name, origin, last, on_done)
	core.emerge_area(origin, last, function(_, action, calls_remaining)
		if action == core.EMERGE_ERRORED then
			core.log("error", "str_start: emerging the interior of " .. name .. " failed")
		end
		if calls_remaining > 0 then
			return
		end
		on_done(core.get_player_by_name(name))
	end)
end

-- The display entities are not saved; delay (seconds) is optional. Unowned diggers go to the slot's player
local function ensure_diggers(player_name, origin, last, delay)
	for _, pos in ipairs(core.find_nodes_in_area(origin, last, DIGGER)) do
		str_interior.claim_digger(pos, player_name)
		str_interior.ensure_digger_entity(pos, 5, delay)
	end
end

local placed_listeners = {}

-- fn(player_name, origin, last): a fresh copy of the player's interior was just placed (its blocks are loaded)
function str_start.register_on_interior_placed(fn)
	table.insert(placed_listeners, fn)
end

-- The online player whose interior holds pos, and that interior's origin; nil if none
function str_start.owner_at(pos)
	local size = get_interior_size()
	if not size then
		return nil
	end
	pos = vector.round(pos)
	local slot = math.floor((pos.x - grid.origin.x) / grid.spacing)
	local name = owner_of[slot]
	if not name then
		return nil
	end
	local rel = vector.subtract(pos, slot_origin(slot))
	if rel.x < 0 or rel.y < 0 or rel.z < 0 or rel.x >= size.x or rel.y >= size.y or rel.z >= size.z then
		return nil
	end
	return name, slot_origin(slot)
end

-- A reused slot still holds the last player's copy: their entities, and node meta the schematic keeps
local function place_interior(name, origin, last, digger_delay)
	for obj in core.objects_in_area(vector.offset(origin, -1, -1, -1), vector.offset(last, 1, 1, 1)) do
		if not obj:is_player() then
			obj:remove()
		end
	end
	core.place_schematic(origin, SCHEMATIC, "0", nil, true)
	for _, pos in ipairs(core.find_nodes_with_meta(origin, last)) do
		core.get_meta(pos):from_table(nil)
	end
	for _, fn in ipairs(placed_listeners) do
		fn(name, origin, last)
	end
	ensure_diggers(name, origin, last, digger_delay)
	placed[name] = true
end

-- Loads the player's interior, placing a fresh copy on its first use this session, then calls
-- on_done(player, origin, last), with no player if they left or hold no slot
local function prepare_interior(name, digger_delay, on_done)
	local slot, size, session = slot_of[name], get_interior_size(), session_of[name]
	if not (slot and size) then
		on_done(nil)
		return
	end
	local origin = slot_origin(slot)
	local last = vector.offset(vector.add(origin, size), -1, -1, -1)
	emerge_interior(name, origin, last, function(player)
		if not player or session_of[name] ~= session then
			on_done(nil)
			return
		end
		if not placed[name] then
			place_interior(name, origin, last, digger_delay)
		end
		on_done(player, origin, last)
	end)
end

local LETTER_TEXT = table.concat({
	"<center><big><b>DO YOU LIKE GEMS?</b></big>",
	"<big><b>DO YOU LIKE BEING RICH?</b></big>",
	"<b>WE'VE GOT GOOD NEWS.</b></center>",
	"",
	"Dear Valued Future Millionaire,",
	"",
	"You have been <i>personally selected</i> (along with 40,000 others) for a once-in-a-lifetime opportunity with <b>Excelsior Deep Yield Group</b>: digging for riches on the planet Strata!",
	"",
	"<b>WE PROVIDE:</b>",
	"- A state-of-the-art digging machine*",
	"- Your very own plot of mineral-rich land**",
	"- Your own mechanic shop",
	"- Unlimited earning potential***",
	"",
	"No experience needed! No questions asked!",
	"",
	"Simply sign below and start digging. The only thing between you and a life of luxury is <i>dirt</i>!",
	"",
	"<i>*Machine is \"pre-owned.\" **Land is \"technically\" ours. ***Subject to terms.</i>",
	"",
	"Sincerely,",
	"<i>Chad Brightwell, Vice President of Your Success</i>",
	"",
	"<mono>Terms and conditions are available upon request, in a separate building, during business hours that don't exist.</mono>",
}, "\n")

local LETTER_FORM = "str_start:letter"
local LETTER_KEY = "str_start:letter_agreed"

local function show_letter(name)
	local fs = "formspec_version[9]size[11,15.6]no_prepend[]allow_close[false]bgcolor[#00000000;true;#000000B4]"
		.. "box[0.5,0.3;10,15;#EBDDA6FF]"
		.. "box[0.5,0.3;10,0.08;#D4C285FF]"
		.. ("hypertext[1.3,1.0;8.4,12.2;letter;<style color=#3B2F1A size=15>%s</style>]")
			:format(core.formspec_escape(LETTER_TEXT))
		.. "style[agree;bgcolor=#00000000;border=false;textcolor=#3B2F1A;font=bold]"
		.. "button[3.5,13.7;4,0.9;agree;Agree]"
	core.show_formspec(name, LETTER_FORM, fs)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname == LETTER_FORM and fields.agree then
		player:get_meta():set_string(LETTER_KEY, "1")
		core.close_formspec(player:get_player_name(), LETTER_FORM)
	end
end)

local function first_spawn(player)
	local name = player:get_player_name()
	local size = get_interior_size()
	if not size then
		core.log("error", "str_start: cannot read " .. SCHEMATIC .. ", spawning normally")
		return
	end
	local origin = str_start.get_origin(player)
	if not origin then
		return
	end
	-- On foot right away so the vehicle mode does not start a machine; the unloaded map holds the player
	str_mode.set(player, "foot")
	player:set_pos(origin)
	prepare_interior(name, DIGGER_SPAWN_DELAY, function(joined, _, last)
		if not joined then
			return -- still not started: the next join tries again
		end
		place_player(joined, origin, last)
		joined:get_meta():set_string(DONE_KEY, "1")
		show_letter(name)
	end)
end

-- player name -> {hud, alpha, t, ready, origin, last} while their interior loads for an entry
local entering = {}
local FADE = 0.6
-- player name -> {t, alpha, switched, hud} while boarding the machine behind a black screen
local boarding = {}
local BOARD_TIMEOUT = 15

local function new_fade_hud(player)
	return player:hud_add({
		type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
		scale = {x = -100, y = -100}, text = "[fill:8x8:#000000^[opacity:0", z_index = 1000,
	})
end

local function set_fade(player, trip, alpha)
	local value = math.floor(math.max(0, math.min(1, alpha)) * 255 + 0.5)
	if value ~= trip.alpha then
		trip.alpha = value
		player:hud_change(trip.hud, "text", "[fill:8x8:#000000^[opacity:" .. value)
	end
end

local function finish_entry(player, name, trip)
	entering[name] = nil
	if trip.hud and player then
		player:hud_remove(trip.hud)
	end
	if not player or str_mode.get(player) ~= "vehicle" then
		return
	end
	local marker = core.find_nodes_in_area(trip.origin, trip.last, SPAWN_MARKER)[1]
	if not marker then
		core.log("error", "str_start: no " .. SPAWN_MARKER .. " in the interior of " .. name)
		core.chat_send_player(name, "Your workshop has no entrance.")
		str_machine.set_frozen(player, false)
		return
	end
	ensure_diggers(name, trip.origin, trip.last)
	str_machine.set_frozen(player, false)
	str_mode.set(player, "foot")
	stand_on(player, marker, FEET_ABOVE_BED, true)
end

core.register_globalstep(function(dtime)
	for name, trip in pairs(entering) do
		local player = core.get_player_by_name(name)
		if not player then
			entering[name] = nil
		else
			trip.t = trip.t + dtime
			set_fade(player, trip, trip.t / FADE)
			if trip.ready and trip.t >= FADE then
				finish_entry(player, name, trip)
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	entering[player:get_player_name()] = nil
end)

-- From driving: fade to black while the player's interior loads, then cut to them on foot at the shop spawn marker
function str_start.enter_workshop(player)
	local name = player:get_player_name()
	if entering[name] or str_mode.get(player) ~= "vehicle" then
		return
	end
	local origin, size = str_start.get_origin(player), get_interior_size()
	if not (origin and size) then
		core.log("error", "str_start: no interior to enter for " .. name)
		core.chat_send_player(name, "Your workshop is not ready yet.")
		return
	end
	local last = vector.offset(vector.add(origin, size), -1, -1, -1)
	local trip = {t = 0, alpha = 0, ready = false, origin = origin, last = last, hud = new_fade_hud(player)}
	entering[name] = trip
	str_machine.set_frozen(player, true)
	prepare_interior(name, nil, function()
		trip.ready = true
	end)
end

-- Saves where the player stands in their interior, relative to its origin; only someone on foot is inside it
local function save_interior_pos(player)
	local name = player:get_player_name()
	local origin, size = str_start.get_origin(player), get_interior_size()
	if not (placed[name] and origin and size) then
		return -- not woken up yet this session: keep the last saved spot
	end
	local meta = player:get_meta()
	meta:set_string(POS_KEY, "")
	local rel = vector.subtract(player:get_pos(), origin)
	if not in_box(rel, size) then
		return
	end
	meta:set_string(POS_KEY, core.write_json({x = rel.x, y = rel.y, z = rel.z,
		yaw = player:get_look_horizontal(), pitch = player:get_look_vertical()}))
end

-- The saved spot at origin, nil if there is none, it is outside the interior, or feet or head are in a full cube
local function saved_interior_pos(raw, origin)
	local saved = raw ~= "" and core.parse_json(raw) or nil
	if type(saved) ~= "table" or not (tonumber(saved.x) and tonumber(saved.y) and tonumber(saved.z)) then
		return nil
	end
	local rel = vector.new(tonumber(saved.x), tonumber(saved.y), tonumber(saved.z))
	local size = get_interior_size()
	if not (size and in_box(rel, size)) then
		return nil
	end
	local pos = vector.add(origin, rel)
	local feet = vector.round(vector.offset(pos, 0, 0.01, 0))
	if full_cube(feet) or full_cube(vector.offset(feet, 0, 1, 0)) then
		return nil
	end
	return pos, tonumber(saved.yaw) or 0, tonumber(saved.pitch) or 0
end

-- A player who quit on foot was in last session's slot: put them on the same spot in this session's copy,
-- or at the entrance if none was saved (older saves, or a crash) or it is now blocked
local function wake_in_interior(player)
	local name = player:get_player_name()
	local origin = str_start.get_origin(player)
	if not origin then
		return
	end
	player:set_pos(origin)
	prepare_interior(name, nil, function(joined, _, last)
		if not joined then
			return
		end
		local meta = joined:get_meta()
		local pos, yaw, pitch = saved_interior_pos(meta:get_string(POS_KEY), origin)
		meta:set_string(POS_KEY, "")
		if pos then
			joined:set_pos(pos)
			joined:set_look_horizontal(yaw)
			joined:set_look_vertical(pitch)
		else
			place_at_entrance(joined, origin, last)
		end
	end)
end

local MENU_FORM = "str_start:workshop"

function str_start.show_workshop_menu(player)
	local cost = str_refuel.full_cost(player)
	local label = cost > 0 and ("Full Refuel (%s credits)"):format(str_player_resources.format_credits(cost))
		or "Full Refuel (tank full)"
	local y = str_gui.CONTENT_Y
	local fs = str_gui.header(8, y + 3.5, "Mechanic shop")
		.. ("button_exit[1,%g;6,0.9;enter;Enter Workshop]"):format(y)
		.. ("button[1,%g;6,0.9;refuel;%s]"):format(y + 1.1, core.formspec_escape(label))
		.. ("button[1,%g;6,0.9;deposit;Deposit All]"):format(y + 2.2)
	core.show_formspec(player:get_player_name(), MENU_FORM, fs)
end

str_audio.sfx.register("storage_deposit", {sound = "str_start_deposit"})

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= MENU_FORM then
		return
	end
	if fields.enter then
		str_start.enter_workshop(player)
	elseif fields.refuel then
		str_refuel.fill_full(player)
		str_start.show_workshop_menu(player)
	elseif fields.deposit then
		if str_storage.deposit_all(player) > 0 then
			str_audio.sfx.play("storage_deposit", {player = player})
		end
		str_start.show_workshop_menu(player)
	end
end)

core.register_on_leaveplayer(function(player)
	entering[player:get_player_name()] = nil
end)

-- Right-clicking the display digger boards the machine, which is respawned at its saved position if gone
str_interior.register_on_use(str_utils.constants.interact.drive, function(player_name)
	local player = core.get_player_by_name(player_name)
	if not player or str_mode.get(player) ~= "foot" then
		return
	end
	if not str_mail.has_read(player_name, "welcome") then
		str_utils.show_popup(player_name, "The vehicle is locked. Check the mail on the computer.")
		return
	end
	if boarding[player_name] then
		return
	end
	boarding[player_name] = {t = 0, alpha = 0, switched = false, hud = new_fade_hud(player)}
end)

core.register_globalstep(function(dtime)
	for name, trip in pairs(boarding) do
		local player = core.get_player_by_name(name)
		if not player then
			boarding[name] = nil
		else
			trip.t = trip.t + dtime
			if not trip.switched then
				set_fade(player, trip, trip.t / FADE)
				if trip.t >= FADE then
					trip.switched, trip.t = true, 0
					str_mode.set(player, "vehicle")
				end
			elseif str_machine.get_pos(player) or trip.t > BOARD_TIMEOUT then
				-- The machine exists: cut from black
				player:hud_remove(trip.hud)
				boarding[name] = nil
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	boarding[player:get_player_name()] = nil
end)

-- Runs after str_mode's join handler, which puts every player in the default mode
core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not claim_slot(name) then
		-- Another join took the last slot after this one passed prejoin
		core.log("warning", "str_start: no free interior slot for " .. name .. ", disconnecting")
		core.disconnect_player(name, FULL_TEXT, true)
		return
	end
	-- Oldest first, so the welcome mail ends up on top
	for _, id in ipairs({"jim", "free_gift", "welcome"}) do
		str_mail.send_story(name, id)
	end
	local meta = player:get_meta()
	for _, key in ipairs(OLD_KEYS) do
		meta:set_string(key, "")
	end
	if meta:get_string(DONE_KEY) == "" then
		first_spawn(player)
		return
	end
	if str_mode.get(player) == "foot" then
		wake_in_interior(player)
	end
	if meta:get_string(LETTER_KEY) == "" then
		show_letter(name)
	end
end)

core.register_on_prejoinplayer(function()
	if not free_slot() then
		return FULL_TEXT
	end
end)

core.register_on_leaveplayer(function(player)
	save_interior_pos(player)
	release_slot(player:get_player_name())
end)

-- Players still online at shutdown get no leave callback; this runs before they are saved
core.register_on_shutdown(function()
	for _, player in ipairs(core.get_connected_players()) do
		save_interior_pos(player)
	end
end)
