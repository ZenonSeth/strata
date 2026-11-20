local HOT = str_utils.constants.hot_rock
local LAVA_DPS = core.registered_nodes["str_nodes:lava_source"].damage_per_second

-- Drilled hot rock: heat on the bar, and lava damage for the share the bar cannot take
str_machine.register_on_dig(function(player, pos, node_name, method)
	local def = core.registered_nodes[node_name]
	if method ~= "drill" or not (def and def.str_hot) then
		return
	end
	str_audio.sfx.play("sizzle", {player = player})
	-- Deferred so a possible machine loss happens outside the dig step
	local name = player:get_player_name()
	core.after(0, function()
		local p = core.get_player_by_name(name)
		if not p or str_mode.get(p) ~= "vehicle" or str_machine.is_dead(p) then
			return
		end
		local share = str_machine.heat.absorb(p, HOT.heat_seconds)
		if share > 0 then
			str_machine.hull.damage(p, HOT.damage_seconds * LAVA_DPS * share)
		end
	end)
end)
