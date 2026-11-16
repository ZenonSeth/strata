local transmissions = str_transmissions

str_audio.sfx.register("transmission_ping", {sound = "str_transmissions_ping"})

local mod_storage = core.get_mod_storage()
local cache = {}
local listeners = {}

local function key(name)
	return "transmissions:" .. name
end

local function data(name)
	if not cache[name] then
		local raw = mod_storage:get_string(key(name))
		local loaded = raw ~= "" and core.parse_json(raw)
		local d = type(loaded) == "table" and loaded or {}
		d.items = d.items or {}
		-- Story progress: sequence entries done, relic count at the last story signal (nil before the first),
		-- signal waiting for its delay (pending), reply chosen per point (option index), points whose answer
		-- step has passed, late answers waiting, and pending watches
		d.step = d.step or 0
		d.replies, d.answered = d.replies or {}, d.answered or {}
		d.queue, d.watch = d.queue or {}, d.watch or {}
		cache[name] = d
	end
	return cache[name]
end

local function save(name)
	mod_storage:set_string(key(name), core.write_json(data(name)))
	local player = core.get_player_by_name(name)
	if player then
		for _, fn in ipairs(listeners) do
			fn(player)
		end
	end
end

-- fn(player) runs after a player's transmissions change
function transmissions.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

function transmissions.is_unlocked(player)
	return data(player:get_player_name()).unlocked == true
end

-- Makes the Transmissions tab appear; receiving a transmission does this too
function transmissions.unlock(name)
	local d = data(name)
	if not d.unlocked then
		d.unlocked = true
		save(name)
	end
end

-- Oldest first. A received signal is {text = glyph string, analysis =, id =, time =, found = words decoded};
-- a reply the machine sent is {sent = label, time =}.
function transmissions.get(name)
	return table.copy(data(name).items)
end

-- text is a space-separated glyph string (see messages.lua); id is optional and marks a book message as received
function transmissions.add(name, text, analysis, id)
	local d = data(name)
	d.unlocked = true
	d.items[#d.items + 1] = {text = text, analysis = analysis, id = id, time = os.time()}
	save(name)
	local player = core.get_player_by_name(name)
	if player then
		str_audio.sfx.play("transmission_ping", {player = player})
		str_utils.show_popup(name, "Unexpected Transmission Received", 4)
	end
end

local book = {}
for _, message in ipairs(dofile(transmissions.modpath .. "/messages.lua")) do
	book[message.id] = message
end

function transmissions.has_received(name, id)
	for _, item in ipairs(data(name).items) do
		if item.id == id then
			return true
		end
	end
	return false
end

-- Sends a message from messages.lua; returns false if the id is unknown or was already received
function transmissions.send(name, id)
	local message = book[id]
	if not message or transmissions.has_received(name, id) then
		return false
	end
	local text = message.text or transmissions.cipher.to_string(transmissions.cipher.noise(message.noise))
	transmissions.add(name, text, message.analysis, id)
	return true
end

-- Hypertext markup drawing a stored glyph string as images, size pixels square
function transmissions.markup(text, size)
	local out = {}
	for n in text:gmatch("%d+") do
		out[#out + 1] = ("<img name=str_transmissions_glyph_%s.png width=%d height=%d>"):format(n, size, size)
	end
	return table.concat(out)
end

-- Decoding: each plain word is only stored as sha1("strata|<id>|<word index>|<word>"), see tools/cipher.py

-- Same cleaning as tools/cipher.py: lowercase, only a-z, 0-9 and single spaces
local function clean(text)
	return (text:lower():gsub("%s+", " "):gsub("[^a-z0-9 ]", ""))
end

local function signal_words(item)
	local message = item and item.id and book[item.id]
	return message and message.words
end

-- Words of log entry index as decoded so far ("" for each word not found yet); nil if it has no words
function transmissions.revealed(name, index)
	local item = data(name).items[index]
	local words = signal_words(item)
	if not words then
		return nil
	end
	local out = {}
	for i = 1, #words do
		out[i] = item.found and item.found[i] or ""
	end
	return out
end

function transmissions.is_decoded(name, index)
	local revealed = transmissions.revealed(name, index)
	if not revealed then
		return false
	end
	for _, word in ipairs(revealed) do
		if word == "" then
			return false
		end
	end
	return true
end

-- Caps the sha1 work of one attempt
local MAX_DECODE_WORDS = 100

-- Reveals every word of log entry index that matches a word of text; returns how many were new
function transmissions.decode(name, index, text)
	local item = data(name).items[index]
	local found = transmissions.revealed(name, index)
	if not found then
		return 0
	end
	local new, checked = 0, 0
	for word in clean(text):gmatch("%S+") do
		checked = checked + 1
		if checked > MAX_DECODE_WORDS then
			break
		end
		for i, hash in ipairs(signal_words(item)) do
			if found[i] == "" and core.sha1(("strata|%s|%d|%s"):format(item.id, i, word)) == hash then
				found[i] = word
				new = new + 1
			end
		end
	end
	if new > 0 then
		item.found = found
		save(name)
	end
	return new
end

-- Story: signals arrive one per relic step, in story.lua order, and replies pick the answers

local story = dofile(transmissions.modpath .. "/story.lua")
local points = {}
local watch_of = {}
for _, point in ipairs(story.replies) do
	points[point.id] = point
	for _, option in ipairs(point.options) do
		watch_of[option.answer] = option.watch
	end
end

-- Strange object counters per player, kept in mod storage so world resets do not clear them
local relic_cache = {}

local function relic_data(name)
	if not relic_cache[name] then
		local raw = mod_storage:get_string("relics:" .. name)
		local loaded = raw ~= "" and core.parse_json(raw)
		relic_cache[name] = type(loaded) == "table" and loaded or {}
	end
	return relic_cache[name]
end

local function relics_found(name)
	local r = relic_data(name)
	return (r.dug or 0) + (r.destroyed or 0)
end

-- Debug: clears the log, story progress and relic counters
function transmissions.reset(name)
	cache[name], relic_cache[name] = nil, nil
	mod_storage:set_string(key(name), "")
	mod_storage:set_string("relics:" .. name, "")
	save(name)
end

-- Relics before the first signal, rolled once per player on join
local thresholds = {}

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	if meta:get_int("str_transmissions:dlpt") == 0 then
		meta:set_int("str_transmissions:dlpt", math.random(story.first[1], story.first[2]))
	end
	thresholds[player:get_player_name()] = meta:get_int("str_transmissions:dlpt")
end)

-- Log index of the newest signal that opened a reply point, or nil
local function opened_at(name, point)
	local items = data(name).items
	for i = #items, 1, -1 do
		if items[i].id and table.indexof(point.after, items[i].id) > 0 then
			return i
		end
	end
end

-- Next message id for a relic step, advancing the story; nil when the story has run out
local function next_message(name, d)
	if #d.queue > 0 then
		return table.remove(d.queue, 1)
	end
	while d.step < #story.sequence do
		d.step = d.step + 1
		local entry = story.sequence[d.step]
		local id = entry.id
		if entry.answer then
			local point = points[entry.answer]
			local option = point.options[d.replies[point.id]]
			d.answered[point.id] = true
			id = option and option.answer or point.silent
		elseif entry.fate then
			local r = relic_data(name)
			id = (r.destroyed or 0) > (r.dug or 0) and entry.fate.destroyed or entry.fate.dug
		end
		if not transmissions.has_received(name, id) then
			return id
		end
	end
end

-- Seconds between the relic that triggers a signal and its arrival
local DELAY_MIN, DELAY_MAX = 5, 10

local function deliver_pending(name)
	local d = data(name)
	local id = d.pending
	if not id then
		return
	end
	d.pending = nil
	local watch = watch_of[id]
	if watch then
		d.watch[#d.watch + 1] = {at = relics_found(name) + watch.relics, id = watch.id}
	end
	if not transmissions.send(name, id) then
		save(name)
	end
end

-- Kept in storage while waiting, so a signal cut off by a shutdown arrives on the next join
local function schedule(name)
	core.after(math.random(DELAY_MIN, DELAY_MAX), deliver_pending, name)
end

local function check_triggers(name)
	local threshold = thresholds[name]
	if not threshold then
		return
	end
	local d = data(name)
	local found = relics_found(name)
	for i = #d.watch, 1, -1 do
		if found >= d.watch[i].at then
			d.queue[#d.queue + 1] = table.remove(d.watch, i).id
		end
	end
	-- Logs from before story pacing have no count yet: start the next step from here
	if not d.last and #d.items > 0 then
		d.last = found
		save(name)
	end
	if not d.pending and found >= (d.last and d.last + story.step or threshold) then
		local id = next_message(name, d)
		if id then
			d.last, d.pending = found, id
			save(name)
			schedule(name)
		end
	end
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if data(name).pending then
		schedule(name)
	end
end)

local function open_point(name, index)
	local d = data(name)
	for _, point in ipairs(story.replies) do
		if not d.replies[point.id] and opened_at(name, point) == index then
			return point
		end
	end
end

-- Reply options for log entry index, or nil if it has no open reply point: {{label =, enabled =}, ...}
function transmissions.reply_options(name, index)
	local point = open_point(name, index)
	if not point then
		return nil
	end
	local decoded = transmissions.is_decoded(name, index)
	local out = {}
	for i, option in ipairs(point.options) do
		out[i] = {label = option.label, enabled = decoded or not option.decode}
	end
	return out
end

-- Company notices, one per reply sent, mailed once the player is back at the surface; the last sets the hold
local NOTICES = {"corp_signal_1", "corp_signal_2", "corp_signal_3"}
-- Last machine depth per player (0 or less is at or above the pad)
local machine_depth = {}

local function send_notices(player)
	local name = player:get_player_name()
	if str_mode.get(player) ~= "foot" and (machine_depth[name] or 1) > 0 then
		return
	end
	local count = 0
	for _ in pairs(data(name).replies) do
		count = count + 1
	end
	for i = 1, math.min(count, #NOTICES) do
		str_mail.send_story(name, NOTICES[i])
	end
	if count >= #NOTICES and not str_story.get_departure_hold(player) then
		str_story.set_departure_hold(player)
	end
end

str_machine.register_on_depth_change(function(player, depth)
	machine_depth[player:get_player_name()] = depth
	send_notices(player)
end)

str_mode.register_on_change(send_notices)

-- Sends option n of the reply point opened by log entry index; returns false if it is not available
function transmissions.reply(name, index, n)
	local point = open_point(name, index)
	local option = point and point.options[n]
	if not option or (option.decode and not transmissions.is_decoded(name, index)) then
		return false
	end
	local d = data(name)
	d.replies[point.id] = n
	if d.answered[point.id] then
		d.queue[#d.queue + 1] = option.answer
	end
	d.items[#d.items + 1] = {sent = option.label, time = os.time()}
	save(name)
	local player = core.get_player_by_name(name)
	if player then
		send_notices(player)
	end
	return true
end

-- kind is "dug", "discarded", "sold" or "destroyed"; does nothing unless item_name is a strange object
function transmissions.count_relic(name, item_name, kind, amount)
	local def = item_name and str_materials.get(item_name)
	if not def or def.kind ~= "relic" then
		return
	end
	local d = relic_data(name)
	d[kind] = (d[kind] or 0) + (amount or 1)
	mod_storage:set_string("relics:" .. name, core.write_json(d))
	check_triggers(name)
end

function transmissions.relic_count(name, kind)
	return relic_data(name)[kind] or 0
end

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	cache[name] = nil
	relic_cache[name] = nil
	thresholds[name], machine_depth[name] = nil, nil
end)

str_machine.register_on_dig(function(player, pos, node_name, method)
	local def = core.registered_nodes[node_name]
	transmissions.count_relic(player:get_player_name(), def and def.str_material,
		method == "blast" and "destroyed" or "dug")
end)
