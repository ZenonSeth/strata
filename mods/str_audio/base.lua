local music = str_audio.music
local sfx = str_audio.sfx

local META_PREFIX = "str_audio:"

local function clamp01(v)
	return math.max(0, math.min(1, v))
end

-- Global setting, overridable per player through meta; categories are "music" and "sfx"
local function enabled(player, category)
	if not core.settings:get_bool("str_audio_" .. category .. "_enabled", true) then
		return false
	end
	local v = player:get_meta():get_string(META_PREFIX .. category .. "_enabled")
	return v ~= "0"
end

local function volume(player, category)
	local base = tonumber(core.settings:get("str_audio_" .. category .. "_volume")) or 1
	local v = tonumber(player:get_meta():get_string(META_PREFIX .. category .. "_volume")) or 1
	return clamp01(base) * clamp01(v)
end

-- Music: one current track per player

-- Silence between clips of a scheduled track, in seconds
local MIN_GAP, MAX_GAP = 30, 90

local tracks = {}
-- player name -> {track = name, handle = handle or nil, clip = sound or nil, last = clip index, job = job or nil}
local current_music = {}

-- def: {sound = name} for a looping track, or {clips = {{sound = name, length = seconds}, ...}}
-- for a track that plays a random clip (never the same twice in a row) after each stretch of silence
function music.register_track(name, def)
	tracks[name] = {sound = def.sound, clips = def.clips, gain = def.gain or 1, enabled = def.enabled ~= false}
end

function music.set_track_enabled(name, value)
	tracks[name].enabled = value
end

function music.current(player)
	local state = current_music[player:get_player_name()]
	return state and state.track
end

local function halt_sound(state)
	if state.handle then
		core.sound_stop(state.handle)
		state.handle = nil
	end
end

local function halt_music(state)
	if state.job then
		state.job:cancel()
		state.job = nil
	end
	halt_sound(state)
end

local function apply_music(player)
	local pname = player:get_player_name()
	local state = current_music[pname]
	if not state then
		return
	end
	halt_sound(state)
	local def = tracks[state.track]
	local sound = def.sound or state.clip
	if not sound or not def.enabled or not enabled(player, "music") then
		return
	end
	state.handle = core.sound_play(sound, {
		to_player = pname,
		gain = def.gain * volume(player, "music"),
		loop = def.sound ~= nil,
	})
end

local function schedule_clip(pname, state)
	state.clip = nil
	state.job = core.after(math.random(MIN_GAP, MAX_GAP), function()
		local player = core.get_player_by_name(pname)
		if not player or current_music[pname] ~= state then
			return
		end
		if state.can_play and not state.can_play(player) then
			music.stop(player)
			return
		end
		local clips = tracks[state.track].clips
		local i
		repeat
			i = math.random(#clips)
		until i ~= state.last or #clips == 1
		state.last = i
		state.clip = clips[i].sound
		apply_music(player)
		state.job = core.after(clips[i].length, function()
			if current_music[pname] ~= state then
				return
			end
			halt_sound(state)
			schedule_clip(pname, state)
		end)
	end)
end

-- Replaces whatever was playing; remembered while disabled so enabling it later starts it.
-- can_play(player), for a clips track, is checked after each silence; if false the track stops.
function music.play(player, track, can_play)
	local def = tracks[track]
	assert(def, "str_audio: unknown music track '" .. tostring(track) .. "'")
	local pname = player:get_player_name()
	local state = current_music[pname]
	if state and state.track == track and (state.handle or def.clips) then
		return
	end
	if state then
		halt_music(state)
	end
	state = {track = track, can_play = can_play}
	current_music[pname] = state
	if def.clips then
		schedule_clip(pname, state)
	else
		apply_music(player)
	end
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
	assert(def, "str_audio: unknown sfx '" .. tostring(name) .. "'")
	opts = opts or {}
	local player = opts.player
	local category = def.category
	if player and not enabled(player, category) then
		return
	end
	if not core.settings:get_bool("str_audio_" .. category .. "_enabled", true) then
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
	assert(defs[name], "str_audio: unknown sfx '" .. tostring(name) .. "'")
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

function str_audio.set_enabled(player, category, value)
	player:get_meta():set_string(META_PREFIX .. category .. "_enabled", value and "1" or "0")
	refresh(player, category)
end

function str_audio.set_volume(player, category, value)
	player:get_meta():set_string(META_PREFIX .. category .. "_volume", tostring(clamp01(value)))
	refresh(player, category)
end

function str_audio.is_enabled(player, category)
	return enabled(player, category)
end

function str_audio.get_volume(player, category)
	return volume(player, category)
end

-- Settings window rows, in order
str_audio.categories = {
	{id = "music", title = "Music"},
	{id = "sfx", title = "Effects"},
	{id = "vehicle", title = "Machine"},
}

-- The player's own volume (0 to 1), without the server-wide setting that get_volume folds in
function str_audio.get_player_volume(player, category)
	return clamp01(tonumber(player:get_meta():get_string(META_PREFIX .. category .. "_volume")) or 1)
end

core.register_on_leaveplayer(function(player)
	music.stop(player)
	sfx.stop_all_loops(player)
end)

music.register_track("foot", {sound = "str_audio_music_foot", gain = 1.0})

music.register_track("ending", {sound = "str_audio_music_ending", gain = 1.0})

music.register_track("underground", {
	clips = {
		{sound = "str_audio_music_underground_1", length = 63.9},
		{sound = "str_audio_music_underground_2", length = 99.5},
		{sound = "str_audio_music_underground_3", length = 28.8},
	},
	gain = 1.0,
})
