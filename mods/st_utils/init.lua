st_utils = {}

st_utils.constants = dofile(core.get_modpath("st_utils") .. "/constants.lua")

local COMMON_GROUPS = {oddly_breakable_by_hand = 1}

-- Fresh groups table for solid nodes; overrides add to or replace the common ones
function st_utils.get_common_groups(overrides)
	local groups = table.copy(COMMON_GROUPS)
	for k, v in pairs(overrides or {}) do
		groups[k] = v
	end
	return groups
end
