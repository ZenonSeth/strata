local vignette = {}

-- Darkness starts here and reaches full strength at the fade_end passed to update
local FADE_START = -10
-- Opacity at full darkness never goes below this, whatever the upgrades say
local MIN_FULL_OPACITY = 0.25
-- The overlay opacity is rounded to this many steps to limit client texture variants
local OPACITY_STEPS = 100
local TEXTURE = "st_environment_vignette.png"
local SIZE = 256
-- Fully clear inside this radius, fully dark at 1 (both as a fraction of half the image)
local CLEAR_RADIUS = 0.2

local function smoothstep(edge0, edge1, x)
	local t = math.max(0, math.min((x - edge0) / (edge1 - edge0), 1))
	return t * t * (3 - 2 * t)
end

local function generate()
	local pixels = {}
	for py = 0, SIZE - 1 do
		local dy = (py + 0.5) / SIZE * 2 - 1
		for px = 0, SIZE - 1 do
			local dx = (px + 0.5) / SIZE * 2 - 1
			local alpha = smoothstep(CLEAR_RADIUS, 1, math.sqrt(dx * dx + dy * dy))
			pixels[#pixels + 1] = string.char(0, 0, 0, math.floor(alpha * 255 + 0.5))
		end
	end
	return core.encode_png(SIZE, SIZE, table.concat(pixels))
end

core.dynamic_add_media({filename = TEXTURE, filedata = generate()})

-- player name -> {id = hud id or nil, step = opacity step}
local shown = {}

-- y is the machine height; max_opacity (0..1) is the opacity at full darkness
function vignette.update(player, y, fade_end, max_opacity)
	local span = math.max(FADE_START - fade_end, 1)
	local darkness = math.max(0, math.min((FADE_START - y) / span, 1))
	local full = math.min(math.max(max_opacity, MIN_FULL_OPACITY), 1)
	local step = math.floor(darkness * full * OPACITY_STEPS + 0.5)

	local name = player:get_player_name()
	local state = shown[name] or {step = 0}
	shown[name] = state
	if step == state.step then
		return
	end
	state.step = step

	if step == 0 then
		if state.id then
			player:hud_remove(state.id)
			state.id = nil
		end
		return
	end
	local texture = TEXTURE .. "^[opacity:" .. math.floor(step / OPACITY_STEPS * 255 + 0.5)
	if state.id then
		player:hud_change(state.id, "text", texture)
	else
		state.id = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = -100, y = -100}, text = texture, z_index = -100,
		})
	end
end

function vignette.forget(player)
	shown[player:get_player_name()] = nil
end

st_environment.vignette = vignette
