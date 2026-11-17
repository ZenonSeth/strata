str_groups.CARGO_CRATE = "cargo_crate"

-- Whether the node at pos is in group
function str_groups.at(pos, group)
	return core.get_item_group(core.get_node(pos).name, group) > 0
end
