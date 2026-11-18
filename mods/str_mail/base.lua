local mail = str_mail
local limits = str_utils.constants.mail

local mod_storage = core.get_mod_storage()
local cache = {}
local listeners = {}
local read_listeners = {}
local last_send = {}

-- The NPC mail address; player names cannot contain spaces, so it never matches a real player
mail.JIM_NAME = "Jim Harlow"
-- The sender of Jim's replies; colons are not allowed in player names
mail.JIM_SENDER = "npc:jim"

local function key(name)
	return "mail:" .. name
end

local function data(name)
	if not cache[name] then
		local raw = mod_storage:get_string(key(name))
		local loaded = raw ~= "" and core.parse_json(raw)
		cache[name] = type(loaded) == "table" and loaded or {}
		cache[name].items = cache[name].items or {}
		cache[name].next_id = cache[name].next_id or 1
		cache[name].sent = cache[name].sent or {}
		cache[name].jim_pending = cache[name].jim_pending or {}
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

local function find(name, id)
	for i, item in ipairs(data(name).items) do
		if item.id == id then
			return item, i
		end
	end
end

local function find_key(name, key)
	for _, item in ipairs(data(name).items) do
		if item.key == key then
			return item
		end
	end
end

-- fn(player) runs after an online player's mail changes
function mail.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

-- fn(player_name, mail) runs once, when a mail goes from unread to read; mail is the full copy (with its key)
function mail.register_on_read(fn)
	read_listeners[#read_listeners + 1] = fn
end

-- Adds a mail for a player (online or not); def = {from, subject, text, key, sender, credits}. from, subject and text are strings.
-- credits (optional number) is an attachment: it is kept on the mail and listeners of register_on_read pay it out.
-- key (optional string) names the mail for lookups and is unique per player: sending an existing key does
-- nothing and returns that mail's id. Keyed mails cannot be deleted.
-- sender (optional string) is who a reply goes to: a player name or mail.JIM_SENDER. Returns the mail's id
function mail.send(name, def)
	assert(type(def.from) == "string" and type(def.subject) == "string" and type(def.text) == "string",
		"str_mail.send: from, subject and text must be strings")
	assert(def.key == nil or type(def.key) == "string", "str_mail.send: key must be a string")
	assert(def.sender == nil or type(def.sender) == "string", "str_mail.send: sender must be a string")
	local existing = def.key and find_key(name, def.key)
	if existing then
		return existing.id
	end
	local d = data(name)
	local id = d.next_id
	d.next_id = id + 1
	d.items[#d.items + 1] = {id = id, key = def.key, sender = def.sender, from = def.from, subject = def.subject,
		text = def.text, credits = def.credits, time = os.time(), read = false}
	save(name)
	if not core.get_player_by_name(name) then
		cache[name] = nil
	end
	return id
end

function mail.is_jim(address)
	return address:trim():lower() == mail.JIM_NAME:lower()
end

-- Sends a mail written by a player, to another player (online or not) or to mail.JIM_NAME. Keeps a copy in the
-- sender's sent list. Returns true, or false and a message to show the player
function mail.send_from_player(from_name, to, subject, text)
	to, subject, text = to:trim(), subject:trim(), text:trim()
	if to == "" then
		return false, "Enter a recipient."
	elseif subject == "" then
		return false, "Enter a subject."
	elseif text == "" then
		return false, "The message is empty."
	elseif #subject > limits.subject_max then
		return false, ("The subject is too long (max %d)."):format(limits.subject_max)
	elseif #text > limits.text_max then
		return false, ("The message is too long (max %d)."):format(limits.text_max)
	end
	local wait = (last_send[from_name] or -math.huge) + limits.cooldown - os.time()
	if wait > 0 then
		return false, ("Wait %d s before sending again."):format(wait)
	end
	local d = data(from_name)
	if mail.is_jim(to) then
		to = mail.JIM_NAME
		d.jim_pending[#d.jim_pending + 1] = {subject = subject, text = text, time = os.time()}
	elseif to == from_name then
		return false, "You cannot mail yourself."
	elseif not core.player_exists(to) then
		return false, "No such player: " .. to
	else
		mail.send(to, {from = from_name, sender = from_name, subject = subject, text = text})
	end
	last_send[from_name] = os.time()
	d.sent[#d.sent + 1] = {id = d.next_id, to = to, subject = subject, text = text, time = os.time()}
	d.next_id = d.next_id + 1
	while #d.sent > limits.sent_max do
		table.remove(d.sent, 1)
	end
	save(from_name)
	return true
end

-- Oldest first; each is {id, to, subject, time}, without the text
function mail.list_sent(name)
	local out = {}
	for i, item in ipairs(data(name).sent) do
		out[i] = {id = item.id, to = item.to, subject = item.subject, time = item.time}
	end
	return out
end

-- The full sent copy {id, to, subject, text, time}, or nil
function mail.get_sent(name, id)
	for _, item in ipairs(data(name).sent) do
		if item.id == id then
			return table.copy(item)
		end
	end
end

function mail.delete_sent(name, id)
	local sent = data(name).sent
	for i, item in ipairs(sent) do
		if item.id == id then
			table.remove(sent, i)
			save(name)
			return true
		end
	end
	return false
end

-- Sends the story mail from story.lua with this id (keyed by it, so it goes out once). Returns the mail id
function mail.send_story(name, id)
	local story = assert(mail.story[id], "str_mail.send_story: unknown story mail " .. tostring(id))
	return mail.send(name, {from = story.from, subject = story.subject, text = story.text, key = id,
		credits = story.credits})
end

-- Oldest first; each is {id, key, sender, from, subject, time = os.time(), read}, without the text (key and sender may be nil)
function mail.list(name)
	local out = {}
	for i, item in ipairs(data(name).items) do
		out[i] = {id = item.id, key = item.key, sender = item.sender, from = item.from, subject = item.subject,
			time = item.time, read = item.read}
	end
	return out
end

-- The full mail {id, key, sender, from, subject, text, time, read}, or nil. Does not mark it read
function mail.get(name, id)
	local item = find(name, id)
	return item and table.copy(item)
end

function mail.get_by_key(name, key)
	local item = find_key(name, key)
	return item and table.copy(item)
end

-- True once the player has read the mail with this key; false if it is unread or was never sent
function mail.has_read(name, key)
	local item = find_key(name, key)
	return item ~= nil and item.read
end

function mail.unread_count(name)
	local count = 0
	for _, item in ipairs(data(name).items) do
		if not item.read then
			count = count + 1
		end
	end
	return count
end

function mail.mark_read(name, id)
	local item = find(name, id)
	if item and not item.read then
		item.read = true
		save(name)
		for _, fn in ipairs(read_listeners) do
			fn(name, table.copy(item))
		end
	end
end

-- Story mails (keyed) are never deleted: send and has_read rely on them staying
function mail.can_delete(name, id)
	local item = find(name, id)
	return item ~= nil and item.key == nil
end

-- Returns true if it was deleted
function mail.delete(name, id)
	local item, index = find(name, id)
	if item and item.key == nil then
		table.remove(data(name).items, index)
		save(name)
		return true
	end
	return false
end

function mail.reset(name)
	cache[name] = nil
	mod_storage:set_string(key(name), "")
	data(name)
	save(name)
end

core.register_on_leaveplayer(function(player)
	cache[player:get_player_name()] = nil
end)

-- Keeps players from posing as Jim: "JimHarlow", "jim_harlow", "JIM-HARLOW" and the like
core.register_on_prejoinplayer(function(name)
	if name:lower():gsub("[-_]", "") == "jimharlow" then
		return "This name is reserved. Please choose another."
	end
end)
