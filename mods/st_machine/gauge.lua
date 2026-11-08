-- A per-player level (fuel, hull) saved in player meta, capped by a stat
local gauge = {}

-- def: {meta_key = ..., max_stat = name of the stat holding the cap,
-- on_change = optional function(player, level, max)}
function gauge.new(def)
	local self = {}
	local cache = {}

	local function max_level(player)
		return st_machine.stats.get(player)[def.max_stat]
	end

	-- A player with no saved level starts with a full gauge
	local function level(player)
		local name = player:get_player_name()
		if not cache[name] then
			local meta = player:get_meta()
			local saved = tonumber(meta:get_string(def.meta_key))
			cache[name] = saved or max_level(player)
			if not saved then
				meta:set_string(def.meta_key, tostring(cache[name]))
			end
		end
		return math.min(cache[name], max_level(player))
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
		player:get_meta():set_string(def.meta_key, tostring(amount))
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

	return self
end

return gauge
