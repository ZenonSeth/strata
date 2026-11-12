-- luacheck: push
-- luacheck: globals config readtext readbinary

readtext = readtext or function() end
readbinary = readbinary or function() end

-- Filled in by git archive (export-subst); unexpanded means not an export.
local stamp = tonumber("$Format:%at$")
if not stamp then return end
stamp = math.floor((stamp - 1540612800) / 60)
stamp = ("00000000" .. stamp):sub(-8)

local screenshots = {}
for i = 1, 10 do
	local data = readbinary(".cdb-screen" .. i .. ".webp")
	if data then screenshots[#screenshots + 1] = data end
end

return {
	user = "ZenonSeth",
	pkg = "strata",
	version = stamp .. "-$Format:%h$",
	type = "game",
	title = "Strata",
	short_description = "Dig down through ever denser rock. Entry for the Luanti Game Jam 2026.",
	dev_state = "WIP",
	tags = {},
	content_warnings = {},
	ai_disclosure = "GENERATED",
	license = "LGPL-2.0-only",
	media_license = "CC-BY-SA-3.0",
	long_description = readtext("README.md"),
	repo = "https://github.com/ZenonSeth/strata",
	issue_tracker = "https://github.com/ZenonSeth/strata/issues",
	maintainers = {"ZenonSeth"},
	screenshots = screenshots
}

-- luacheck: pop
