-- A per-player level (fuel, hull) saved in player meta, capped by a stat
local gauge = {}

-- def: {meta_key = ..., max_stat = name of the stat holding the cap,
-- on_change = optional function(player, level, max),
-- read = optional function(player) -> saved level or nil, write = optional function(player, level)
-- (instead of the player meta key, for a level kept elsewhere)}
function gauge.new(def)
	local self = {}
	local cache = {}

	local function read(player)
		if def.read then
			return def.read(player)
		end
		return tonumber(player:get_meta():get_string(def.meta_key))
	end

	local function write(player, amount)
		if def.write then
			def.write(player, amount)
		else
			player:get_meta():set_string(def.meta_key, tostring(amount))
		end
	end

	local function max_level(player)
		return str_machine.stats.get(player)[def.max_stat]
	end

	-- A player with no saved level starts with a full gauge
	local function level(player)
		local name = player:get_player_name()
		if not cache[name] then
			local saved = read(player)
			cache[name] = saved or max_level(player)
			if not saved then
				write(player, cache[name])
			end
		end
		local max = max_level(player)
		if cache[name] > max then
			cache[name] = max
			write(player, max)
		end
		return cache[name]
	end

	function self.get(player)
		return level(player)
	end

	function self.is_empty(player)
		return level(player) <= 0
	end

	-- Clamps to 0..max
	function self.set(player, amount)
		amount = math.max(0, math.min(amount, max_level(player)))
		cache[player:get_player_name()] = amount
		write(player, amount)
		self.refresh(player)
	end

	-- Re-sends the current level to on_change, e.g. when the max changed
	function self.refresh(player)
		if def.on_change then
			def.on_change(player, level(player), max_level(player))
		end
	end

	-- Returns how much was actually added
	function self.add(player, amount)
		local before = level(player)
		self.set(player, before + amount)
		return level(player) - before
	end

	-- Returns how much was actually removed (less than amount if it ran out)
	function self.remove(player, amount)
		local before = level(player)
		self.set(player, before - amount)
		return before - level(player)
	end

	function self.forget(player)
		cache[player:get_player_name()] = nil
	end

	-- The level follows the stats; a change only prompts a re-read (which clamps) and a redraw
	str_machine.stats.register_on_change(function(player)
		cache[player:get_player_name()] = nil
		self.refresh(player)
	end)

	return self
end

str_machine.gauge = gauge
