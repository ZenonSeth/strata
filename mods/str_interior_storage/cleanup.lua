local DEFAULT_WEEKS = 8
local WEEK = 7 * 24 * 3600
local PER_STEP = 20

-- The cleanup in progress: {caller, weeks, cutoff, names, i, removed, dirty, kept}
local run

local function report(text)
	core.log("action", "[str_interior_storage] " .. text)
	if core.get_player_by_name(run.caller) then
		core.chat_send_player(run.caller, text)
	end
end

-- Last login before cutoff, or no account; an unknown login time (nil or -1) keeps the data
local function stale(name, cutoff)
	local auth = core.get_auth_handler().get_auth(name)
	if not auth then
		return true
	end
	local last = tonumber(auth.last_login)
	return last ~= nil and last >= 0 and last < cutoff
end

local function progress()
	return ("Interior cleanup: %d of %d checked, %d removed"):format(run.i - 1, #run.names, run.removed)
end

core.register_globalstep(function()
	if not run then
		return
	end
	for _ = 1, PER_STEP do
		local name = run.names[run.i]
		if not name then
			report(("Interior cleanup done (%g weeks): %d checked, %d removed, %d kept as dirty, %d online or recent")
				:format(run.weeks, #run.names, run.removed, run.dirty, run.kept))
			run = nil
			return
		end
		run.i = run.i + 1
		if core.get_player_by_name(name) or not stale(name, run.cutoff) then
			run.kept = run.kept + 1
		elseif str_interior_storage.is_dirty(name) then
			run.dirty = run.dirty + 1
		else
			str_interior_storage.clear(name)
			run.removed = run.removed + 1
		end
	end
end)

core.register_chatcommand("interior_cleanup", {
	params = "[weeks]",
	description = ("Remove saved interior state of players not seen for [weeks] (default %d),"
		.. " unless it holds real changes"):format(DEFAULT_WEEKS),
	privs = {server = true},
	func = function(name, param)
		if run then
			return false, "Already running. " .. progress()
		end
		param = param:trim()
		local weeks = param == "" and DEFAULT_WEEKS or tonumber(param)
		if not (weeks and weeks > 0 and weeks < math.huge) then
			return false, "Usage: /interior_cleanup [weeks], with weeks a positive number"
		end
		local names = str_interior_storage.saved_players()
		run = {caller = name, weeks = weeks, cutoff = os.time() - weeks * WEEK, names = names,
			i = 1, removed = 0, dirty = 0, kept = 0}
		core.log("action", ("[str_interior_storage] %s started an interior cleanup (%g weeks, %d saved)")
			:format(name, weeks, #names))
		return true, ("Interior cleanup started: checking %d saved interiors not seen for %g weeks"):format(#names, weeks)
	end,
})
