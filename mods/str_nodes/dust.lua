local colors = dofile(str_nodes.modpath .. "/node_colors.lua")

local FALLBACK = {"#a89888"}
local cache = {}

local function tile_name(tile)
	return type(tile) == "table" and tile.name or tile
end

local function add_file_colors(pool, tile, count)
	local file = tile and tile_name(tile):match("([%w_]+%.png)")
	for i, c in ipairs(file and colors[file] or {}) do
		if i <= count then
			pool[#pool + 1] = c
		end
	end
end

-- Colours for the dust of a dug node: its rock's two main colours plus the ore or gem colour
function str_nodes.dust_colors(node_name)
	if cache[node_name] then
		return cache[node_name]
	end
	local def = core.registered_nodes[node_name] or {}
	local pool = {}
	local base = def.tiles and tile_name(def.tiles[1])
	if base then
		local fill = base:match("^%[fill:%d+x%d+:(#%x+)$")
		if fill then
			pool[1] = fill
		else
			add_file_colors(pool, base, 2)
		end
	end
	add_file_colors(pool, def.overlay_tiles and def.overlay_tiles[1], 1)
	cache[node_name] = #pool > 0 and pool or FALLBACK
	return cache[node_name]
end
