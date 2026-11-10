st_audio = {
	music = {},
	sfx = {},
}

local music = st_audio.music
local sfx = st_audio.sfx

local META_PREFIX = "st_audio:"

local function clamp01(v)
	return math.max(0, math.min(1, v))
end

-- Global setting, overridable per player through meta; categories are "music" and "sfx"
local function enabled(player, category)
	if not core.settings:get_bool("st_audio_" .. category .. "_enabled", true) then
		return false
	end
	local v = player:get_meta():get_string(META_PREFIX .. category .. "_enabled")
	return v ~= "0"
end

local function volume(player, category)
	local base = tonumber(core.settings:get("st_audio_" .. category .. "_volume")) or 1
	local v = tonumber(player:get_meta():get_string(META_PREFIX .. category .. "_volume")) or 1
	return clamp01(base) * clamp01(v)
end

-- Music: one current track per player

local tracks = {}
-- player name -> {track = name, handle = handle or nil}
local current_music = {}

function music.register_track(name, def)
	tracks[name] = {sound = def.sound, gain = def.gain or 1, enabled = def.enabled ~= false}
end

function music.set_track_enabled(name, value)
	tracks[name].enabled = value
end

local function halt_music(state)
	if state.handle then
		core.sound_stop(state.handle)
		state.handle = nil
	end
end

local function apply_music(player)
	local pname = player:get_player_name()
	local state = current_music[pname]
	if not state then
		return
	end
	halt_music(state)
	local def = tracks[state.track]
	if not def.enabled or not enabled(player, "music") then
		return
	end
	state.handle = core.sound_play(def.sound, {
		to_player = pname,
		gain = def.gain * volume(player, "music"),
		loop = true,
	})
end

-- Replaces whatever was playing; remembered while disabled so enabling it later starts it
function music.play(player, track)
	assert(tracks[track], "st_audio: unknown music track '" .. tostring(track) .. "'")
	local pname = player:get_player_name()
	local state = current_music[pname]
	if state and state.track == track and state.handle then
		return
	end
	if state then
		halt_music(state)
	end
	current_music[pname] = {track = track}
	apply_music(player)
end

function music.stop(player)
	local pname = player:get_player_name()
	local state = current_music[pname]
	if state then
		halt_music(state)
		current_music[pname] = nil
	end
end

-- Sound effects: one-shots overlap freely; loops live in named slots per player.
-- Each effect has a category ("sfx" by default, "vehicle" for machine sounds) with its own settings.

local defs = {}
-- player name -> slot -> {sfx = name, opts = table, handle = handle or nil}
local loops = {}

function sfx.register(name, def)
	defs[name] = {
		sound = def.sound,
		category = def.category or "sfx",
		gain = def.gain or 1,
		pitch = def.pitch,
		max_hear_distance = def.max_hear_distance,
	}
end

-- opts: player (only they hear it) or pos (everyone near), exclude_player, gain, pitch
function sfx.play(name, opts)
	local def = defs[name]
	assert(def, "st_audio: unknown sfx '" .. tostring(name) .. "'")
	opts = opts or {}
	local player = opts.player
	local category = def.category
	if player and not enabled(player, category) then
		return
	end
	if not core.settings:get_bool("st_audio_" .. category .. "_enabled", true) then
		return
	end
	local params = {
		gain = def.gain * (opts.gain or 1) * (player and volume(player, category) or 1),
		pitch = opts.pitch or def.pitch,
		max_hear_distance = def.max_hear_distance,
		exclude_player = opts.exclude_player,
	}
	if player then
		params.to_player = player:get_player_name()
	elseif opts.pos then
		params.pos = opts.pos
	end
	return core.sound_play(def.sound, params)
end

local function halt_loop(entry)
	if entry.handle then
		core.sound_stop(entry.handle)
		entry.handle = nil
	end
end

local function apply_loop(player, entry)
	halt_loop(entry)
	local def = defs[entry.sfx]
	if not enabled(player, def.category) then
		return
	end
	entry.handle = core.sound_play(def.sound, {
		to_player = player:get_player_name(),
		gain = def.gain * (entry.opts.gain or 1) * volume(player, def.category),
		pitch = entry.opts.pitch or def.pitch,
		loop = true,
	})
end

-- A slot holds one loop; starting another sfx in it replaces the old one (e.g. low hum -> high hum)
function sfx.start_loop(player, slot, name, opts)
	assert(defs[name], "st_audio: unknown sfx '" .. tostring(name) .. "'")
	local pname = player:get_player_name()
	local slots = loops[pname] or {}
	loops[pname] = slots
	local entry = slots[slot]
	if entry and entry.sfx == name and entry.handle then
		return
	end
	if entry then
		halt_loop(entry)
	end
	entry = {sfx = name, opts = opts or {}}
	slots[slot] = entry
	apply_loop(player, entry)
end

function sfx.stop_loop(player, slot)
	local slots = loops[player:get_player_name()]
	local entry = slots and slots[slot]
	if entry then
		halt_loop(entry)
		slots[slot] = nil
	end
end

function sfx.stop_all_loops(player)
	local pname = player:get_player_name()
	for _, entry in pairs(loops[pname] or {}) do
		halt_loop(entry)
	end
	loops[pname] = nil
end

-- Per-player options; settings GUI can call these later

local function refresh(player, category)
	if category == "music" then
		apply_music(player)
	else
		for _, entry in pairs(loops[player:get_player_name()] or {}) do
			if defs[entry.sfx].category == category then
				apply_loop(player, entry)
			end
		end
	end
end

function st_audio.set_enabled(player, category, value)
	player:get_meta():set_string(META_PREFIX .. category .. "_enabled", value and "1" or "0")
	refresh(player, category)
end

function st_audio.set_volume(player, category, value)
	player:get_meta():set_string(META_PREFIX .. category .. "_volume", tostring(clamp01(value)))
	refresh(player, category)
end

function st_audio.is_enabled(player, category)
	return enabled(player, category)
end

function st_audio.get_volume(player, category)
	return volume(player, category)
end

core.register_on_leaveplayer(function(player)
	music.stop(player)
	sfx.stop_all_loops(player)
end)

music.register_track("foot", {sound = "st_audio_music_foot", gain = 1.0})
