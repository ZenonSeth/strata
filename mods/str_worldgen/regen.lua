local BLOCK = core.MAP_BLOCKSIZE
local SLICE_Z = str_utils.constants.slice_z
-- The liquid stop layer, whose node at each mapblock's lowest x and y corner holds the cycle mark
local MARK_Z = SLICE_Z - 1
local SLICE_BLOCK_Z = math.floor(MARK_Z / BLOCK)

-- Loaded on first use, once every node is registered
local terrain, c_air
local data, param2, out, out2 = {}, {}, {}, {}

-- The cycle mark (mod 256) of slice mapblock bp, or nil if it has no liquid stop corner
function str_worldgen.block_mark(bp)
	local node = core.get_node(vector.new(bp.x * BLOCK, bp.y * BLOCK, MARK_Z))
	return node.name == "str_nodes:liquid_stop" and node.param2 or nil
end

function str_worldgen.current_mark(z)
	return str_worldgen.get_cycle(z) % 256
end

-- Regenerates slice mapblock bp and the backing wall behind it with the current cycle, clearing
-- their node meta. Only blocks below y = 0 are touched. Returns the regenerated minp, maxp.
function str_worldgen.regenerate_block(bp)
	if bp.y >= 0 or bp.z ~= SLICE_BLOCK_Z then
		return nil
	end
	terrain = terrain or dofile(str_worldgen.modpath .. "/terrain.lua")
	c_air = c_air or core.get_content_id("air")
	local minp = vector.new(bp.x * BLOCK, bp.y * BLOCK, SLICE_BLOCK_Z * BLOCK)
	local maxp = vector.new(minp.x + BLOCK - 1, minp.y + BLOCK - 1, SLICE_Z + terrain.BACK_DEPTH)

	-- The neighbours are only read (the rock shapes on the edges need them); dst writes just the column
	local src = core.get_voxel_manip(vector.subtract(minp, 1), vector.add(maxp, 1))
	local area = VoxelArea(src:get_emerged_area())
	src:get_data(data)
	src:get_param2_data(param2)
	for i in area:iterp(minp, maxp) do
		data[i], param2[i] = c_air, 0
	end
	terrain.generate(data, param2, area, minp, maxp, str_worldgen.get_cycle(SLICE_Z))

	local dst = core.get_voxel_manip(minp, maxp)
	local dst_area = VoxelArea(dst:get_emerged_area())
	dst:get_data(out)
	dst:get_param2_data(out2)
	for z = minp.z, maxp.z do
		for y = minp.y, maxp.y do
			local i, j = dst_area:index(minp.x, y, z), area:index(minp.x, y, z)
			for _ = minp.x, maxp.x do
				out[i], out2[i] = data[j], param2[j]
				i, j = i + 1, j + 1
			end
		end
	end
	for _, pos in ipairs(core.find_nodes_with_meta(minp, maxp)) do
		core.get_meta(pos):from_table(nil)
	end
	dst:set_data(out)
	dst:set_param2_data(out2)
	dst:write_to_map(true)
	return minp, maxp
end
