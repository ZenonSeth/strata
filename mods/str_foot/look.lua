-- The body's look, kept in player meta: which model, and the tint of each grey texture layer
local META_KEY = "str_foot:look"

local CHOICES = {
	body = {male = true, female = true},
	top = {short = true, long = true},
	bottom = {short = true, long = true},
	hair = {short = true, long = true},
	beard = {[true] = true, [false] = true},
	ponytail = {[true] = true, [false] = true},
}
local DEFAULT = {
	body = "male", top = "long", bottom = "long", hair = "short", beard = false, ponytail = false,
	colours = {skin = "#ddaa86", hair = "#604028", top = "#b05434", bottom = "#465470", shoes = "#3a322e"},
}
local BEARD_SHADE = 0.83 -- of the hair colour

-- player name -> checked look
local cache = {}

local function is_colour(value)
	return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

-- A whole look from any value: missing and invalid fields take the default
local function checked(value)
	local look = table.copy(DEFAULT)
	if type(value) ~= "table" then
		return look
	end
	for field, allowed in pairs(CHOICES) do
		local choice = value[field]
		if choice ~= nil and allowed[choice] then
			look[field] = choice
		end
	end
	if type(value.colours) == "table" then
		for key in pairs(DEFAULT.colours) do
			if is_colour(value.colours[key]) then
				look.colours[key] = value.colours[key]
			end
		end
	end
	return look
end

-- Returns a copy: change it and hand it to set_look
function str_foot.get_look(player)
	local name = player:get_player_name()
	if not cache[name] then
		local raw = player:get_meta():get_string(META_KEY)
		cache[name] = checked(raw ~= "" and core.parse_json(raw))
	end
	return table.copy(cache[name])
end

-- The beard choice is kept while female, so it is back on switching to male
function str_foot.can_have_beard(look)
	return look.body == "male"
end

local function shaded(colour, factor)
	return "#" .. colour:sub(2):gsub("%x%x", function(pair)
		return ("%02x"):format(math.floor(tonumber(pair, 16) * factor))
	end)
end

local function tinted(layer, colour)
	return ("(str_foot_%s.png^[multiply:%s)"):format(layer, colour)
end

-- Returns the mesh and its three textures: body, hair shell, ponytail
function str_foot.get_model(look)
	local mesh = ("str_foot_%s_top_%s_bottom_%s.glb"):format(look.body, look.top, look.bottom)
	local colours = look.colours
	local body = table.concat({
		tinted("skin", colours.skin),
		tinted("bottom_" .. look.bottom, colours.bottom),
		tinted("top_" .. look.top, colours.top),
		tinted("shoes", colours.shoes),
	}, "^")
	-- The face is on the hair shell, which has three times the body's resolution
	local hair = table.concat({
		tinted("undereye", colours.skin),
		"str_foot_face.png",
		tinted("brows_" .. look.body, colours.hair),
		tinted("hair_" .. look.hair, colours.hair),
	}, "^")
	if look.beard and str_foot.can_have_beard(look) then
		hair = hair .. "^" .. tinted("hair_beard", shaded(colours.hair, BEARD_SHADE))
	end
	local tail = look.ponytail and tinted("hair_ponytail", colours.hair) or "blank.png"
	return mesh, {body, hair, tail}
end

-- Saves and shows a look
function str_foot.set_look(player, look)
	local new = checked(look)
	cache[player:get_player_name()] = new
	player:get_meta():set_string(META_KEY, core.write_json(new))
	local mesh, textures = str_foot.get_model(new)
	player:set_properties({mesh = mesh, textures = textures})
end

core.register_on_leaveplayer(function(player)
	cache[player:get_player_name()] = nil
end)
