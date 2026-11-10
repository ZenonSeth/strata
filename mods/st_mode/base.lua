-- Mode a player with no saved mode starts in
local DEFAULT_MODE = "vehicle"
local MODE_KEY = "st_mode:mode"

local modes = {}
-- player name -> mode name
local current = {}
local listeners = {}

-- def: {on_enter = function(player), on_exit = function(player),
-- on_step = function(player, dtime)}, all optional
function st_mode.register_mode(name, def)
	modes[name] = def
end

-- fn(player, new_mode, old_mode); old_mode is nil on join
function st_mode.register_on_change(fn)
	listeners[#listeners + 1] = fn
end

function st_mode.get(player)
	return current[player:get_player_name()]
end

function st_mode.set(player, name)
	local def = modes[name]
	if not def then
		error("st_mode: unknown mode '" .. tostring(name) .. "'")
	end
	local player_name = player:get_player_name()
	local old = current[player_name]
	if old == name then
		return
	end
	if old and modes[old].on_exit then
		modes[old].on_exit(player)
	end
	current[player_name] = name
	player:get_meta():set_string(MODE_KEY, name)
	if def.on_enter then
		def.on_enter(player)
	end
	for _, fn in ipairs(listeners) do
		fn(player, name, old)
	end
end

core.register_globalstep(function(dtime)
	for _, player in ipairs(core.get_connected_players()) do
		local mode = current[player:get_player_name()]
		local on_step = mode and modes[mode].on_step
		if on_step then
			on_step(player, dtime)
		end
	end
end)

core.register_on_joinplayer(function(player)
	local saved = player:get_meta():get_string(MODE_KEY)
	st_mode.set(player, modes[saved] and saved or DEFAULT_MODE)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local mode = current[name]
	if mode and modes[mode].on_exit then
		modes[mode].on_exit(player)
	end
	current[name] = nil
end)
