-- Glyph strings only. The key is in the game only locked with sig_12's plain text; see messages.lua.
local cipher = {}
str_transmissions.cipher = cipher

cipher.count = 37

-- Glyph lists are stored as space-separated numbers
function cipher.to_string(glyphs)
	return table.concat(glyphs, " ")
end

function cipher.from_string(text)
	local glyphs = {}
	for n in text:gmatch("%d+") do
		glyphs[#glyphs + 1] = tonumber(n)
	end
	return glyphs
end

-- Random glyphs with no meaning, for noise transmissions
function cipher.noise(length)
	local glyphs = {}
	for i = 1, length do
		glyphs[i] = math.random(cipher.count)
	end
	return glyphs
end
