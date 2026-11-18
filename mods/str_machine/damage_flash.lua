-- Brief red tint at the screen edges when the hull takes damage, seen only by its driver
local TEXTURE = "str_machine_damage_flash.png"
local SIZE = 128
-- Fully clear inside this radius, full red at 1 (as a fraction of half the image)
local CLEAR_RADIUS = 0.35
local COLOR = {r = 200, g = 0, b = 0}
local MAX_OPACITY = 0.35
local MIN_OPACITY = 0.15
-- Damage that gives the full flash
local FULL_AT = 20
local FADE_TIME = 0.5
local OPACITY_STEPS = 32

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
			pixels[#pixels + 1] = string.char(COLOR.r, COLOR.g, COLOR.b, math.floor(alpha * 255 + 0.5))
		end
	end
	return core.encode_png(SIZE, SIZE, table.concat(pixels))
end

core.dynamic_add_media({filename = TEXTURE, filedata = generate()})

-- player name -> {id, opacity, step}; memory only
local flashes = {}

local function texture(step)
	return TEXTURE .. "^[opacity:" .. math.floor(step / OPACITY_STEPS * 255 + 0.5)
end

local function show(player, flash)
	local step = math.floor(flash.opacity * OPACITY_STEPS + 0.5)
	if step == flash.step then
		return
	end
	flash.step = step
	if flash.id then
		player:hud_change(flash.id, "text", texture(step))
	else
		flash.id = player:hud_add({
			type = "image", position = {x = 0.5, y = 0.5}, alignment = {x = 0, y = 0},
			scale = {x = -100, y = -100}, text = texture(step), z_index = -90,
		})
	end
end

str_machine.hull.register_on_damage(function(player, applied)
	local name = player:get_player_name()
	local opacity = MIN_OPACITY + (MAX_OPACITY - MIN_OPACITY) * math.min(applied / FULL_AT, 1)
	local flash = flashes[name] or {opacity = 0}
	flashes[name] = flash
	flash.opacity = math.max(flash.opacity, opacity)
	show(player, flash)
end)

core.register_globalstep(function(dtime)
	for name, flash in pairs(flashes) do
		local player = core.get_player_by_name(name)
		if not player then
			flashes[name] = nil
		else
			flash.opacity = flash.opacity - dtime * MAX_OPACITY / FADE_TIME
			if flash.opacity <= 0 then
				if flash.id then
					player:hud_remove(flash.id)
				end
				flashes[name] = nil
			else
				show(player, flash)
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	flashes[player:get_player_name()] = nil
end)
