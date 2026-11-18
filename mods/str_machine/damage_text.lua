-- Floating red "-N" numbers over the machine when the hull takes damage, seen only by its driver
local SIZE = 6 -- particle size in tenths of a node
local RISE = 1.0
local LIFE = 0.8
local WINDOW = 0.3
local OFFSET = vector.new(0, 0.8, -0.5)
local MAX_SHOWN = 999
local SCALE = 4
local TEXT_COLOR = 0xFFFF4040
local OUTLINE_COLOR = 0xFF200808

local GLYPHS = {
	["0"] = {"###", "#.#", "#.#", "#.#", "###"},
	["1"] = {".#.", "##.", ".#.", ".#.", "###"},
	["2"] = {"###", "..#", "###", "#..", "###"},
	["3"] = {"###", "..#", ".##", "..#", "###"},
	["4"] = {"#.#", "#.#", "###", "..#", "..#"},
	["5"] = {"###", "#..", "###", "..#", "###"},
	["6"] = {"###", "#..", "###", "#.#", "###"},
	["7"] = {"###", "..#", ".#.", ".#.", ".#."},
	["8"] = {"###", "#.#", "###", "#.#", "###"},
	["9"] = {"###", "#.#", "###", "..#", "###"},
	["-"] = {"...", "...", "###", "...", "..."},
}
local GLYPH_W, GLYPH_H = 3, 5
-- Four glyphs with 1px gaps plus a 1px outline on each side
local CANVAS = 4 * GLYPH_W + 3 + 2

local textures = {}

local function texture(value)
	if textures[value] then
		return textures[value]
	end
	local text = "-" .. value
	local text_w = #text * (GLYPH_W + 1) - 1
	local x0 = math.floor((CANVAS - text_w) / 2)
	local y0 = math.floor((CANVAS - GLYPH_H) / 2)
	local lit = {}
	for i = 1, #text do
		local glyph = GLYPHS[text:sub(i, i)]
		for gy = 1, GLYPH_H do
			for gx = 1, GLYPH_W do
				if glyph[gy]:sub(gx, gx) == "#" then
					lit[(y0 + gy - 1) * CANVAS + x0 + (i - 1) * (GLYPH_W + 1) + gx - 1] = true
				end
			end
		end
	end
	local function pixel(x, y)
		if lit[y * CANVAS + x] then
			return TEXT_COLOR
		end
		for dy = -1, 1 do
			for dx = -1, 1 do
				local nx, ny = x + dx, y + dy
				if nx >= 0 and ny >= 0 and nx < CANVAS and ny < CANVAS and lit[ny * CANVAS + nx] then
					return OUTLINE_COLOR
				end
			end
		end
		return 0x00000000
	end
	-- Pre-scaled so client texture filtering does not blur the tiny glyphs
	local size = CANVAS * SCALE
	local data = {}
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			data[y * size + x + 1] = pixel(math.floor(x / SCALE), math.floor(y / SCALE))
		end
	end
	local tex = "[png:" .. core.encode_base64(core.encode_png(size, size, data))
	textures[value] = tex
	return tex
end

-- player name -> {amount, pos}; damage summed over WINDOW, memory only
local pending = {}

local function flush(name)
	local entry = pending[name]
	local value = math.floor(entry.amount + 0.5)
	if value < 1 then
		-- Keep the leftover so slow drips still add up to a number
		entry.flushing = nil
		return
	end
	pending[name] = nil
	if not core.get_player_by_name(name) or not entry.pos then
		return
	end
	core.add_particle({
		playername = name,
		pos = vector.offset(vector.add(entry.pos, OFFSET), (math.random() - 0.5) * 0.4, 0, 0),
		velocity = vector.new(0, RISE, 0),
		expirationtime = LIFE,
		size = SIZE,
		glow = 14,
		texture = {name = texture(math.min(value, MAX_SHOWN)), blend = "alpha", alpha_tween = {1, 0}},
	})
end

str_machine.hull.register_on_damage(function(player, applied)
	local name = player:get_player_name()
	local entry = pending[name]
	if not entry then
		entry = {amount = 0}
		pending[name] = entry
	end
	entry.amount = entry.amount + applied
	entry.pos = str_machine.get_pos(player) or entry.pos
	if not entry.flushing then
		entry.flushing = true
		core.after(WINDOW, function()
			if pending[name] == entry then
				flush(name)
			end
		end)
	end
end)

core.register_on_leaveplayer(function(player)
	pending[player:get_player_name()] = nil
end)
