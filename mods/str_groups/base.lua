str_groups.CARGO_CRATE = "cargo_crate"
-- Interior nodes whose name is per-player state (e.g. door open/closed), kept across sessions by str_interior_storage
str_groups.SAVED_STATE = "str_saved_state"
-- The invisible layer in front of the slice that keeps liquids in it, plain or glowing
str_groups.LIQUID_STOP = "str_liquid_stop"

-- Whether the node at pos is in group
function str_groups.at(pos, group)
	return core.get_item_group(core.get_node(pos).name, group) > 0
end
