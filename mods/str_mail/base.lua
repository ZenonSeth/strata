local mail = str_mail

local mod_storage = core.get_mod_storage()
local cache = {}
local listeners = {}
local read_listeners = {}

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

-- Adds a mail for a player (online or not); def = {from, subject, text, key, credits}. from, subject and text are strings.
-- credits (optional number) is an attachment: it is kept on the mail and listeners of register_on_read pay it out.
-- key (optional string) names the mail for lookups and is unique per player: sending an existing key does
-- nothing and returns that mail's id. Returns the mail's id
function mail.send(name, def)
	assert(type(def.from) == "string" and type(def.subject) == "string" and type(def.text) == "string",
		"str_mail.send: from, subject and text must be strings")
	assert(def.key == nil or type(def.key) == "string", "str_mail.send: key must be a string")
	local existing = def.key and find_key(name, def.key)
	if existing then
		return existing.id
	end
	local d = data(name)
	local id = d.next_id
	d.next_id = id + 1
	d.items[#d.items + 1] = {id = id, key = def.key, from = def.from, subject = def.subject, text = def.text,
		credits = def.credits, time = os.time(), read = false}
	save(name)
	if not core.get_player_by_name(name) then
		cache[name] = nil
	end
	return id
end

-- Sends the story mail from story.lua with this id (keyed by it, so it goes out once). Returns the mail id
function mail.send_story(name, id)
	local story = assert(mail.story[id], "str_mail.send_story: unknown story mail " .. tostring(id))
	return mail.send(name, {from = story.from, subject = story.subject, text = story.text, key = id,
		credits = story.credits})
end

-- Oldest first; each is {id, key, from, subject, time = os.time(), read}, without the text (key may be nil)
function mail.list(name)
	local out = {}
	for i, item in ipairs(data(name).items) do
		out[i] = {id = item.id, key = item.key, from = item.from, subject = item.subject, time = item.time, read = item.read}
	end
	return out
end

-- The full mail {id, key, from, subject, text, time, read}, or nil. Does not mark it read
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

function mail.delete(name, id)
	local _, index = find(name, id)
	if index then
		table.remove(data(name).items, index)
		save(name)
	end
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
