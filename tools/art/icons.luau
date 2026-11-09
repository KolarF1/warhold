--!strict
-- Our UI glyphs. Every glyph of a thing in the world (a building, a blow, a doctrine, a landmark, money) is a
-- game-icons.net drawing (CC BY 3.0; tools/art/gi_icons.json names each, tools/art/gi_import.py fits it to the grid,
-- authors credited in NOTICE.md and on the licence screen). The plain interface symbols (close, check, play, the clock,
-- the log lines...), our own brand mark and the category frames are drawn here from shapes on the 64 x 64 grid
-- (tools/art/raster.luau describes the shape lists). Judged on the review sheet (tools/art/icon_sheet.luau, then
-- python tools/art/icon_sheet.py --views). Every name the interface asks for (UITheme.icon) is here: tests/art_pack.luau
-- checks the list against the code.
local Frames = require("../../src/shared/Art/Frames")
local Paths = require("./gi_paths")

local I = {}

local pi, cos, sin = math.pi, math.cos, math.sin

local function poly(pts: { number }): { any }
	local out: { any } = { "poly" }
	for _, v in pts do
		table.insert(out, v)
	end
	return out
end

--- A regular polygon-ish outline from a radius function of the angle.
local function outline(cx: number, cy: number, n: number, rf: (number) -> number): { any }
	local pts = {}
	for i = 0, n - 1 do
		local a = (i / n) * 2 * pi - pi / 2
		local r = rf(a)
		table.insert(pts, cx + cos(a) * r)
		table.insert(pts, cy + sin(a) * r)
	end
	return poly(pts)
end

local function star(cx: number, cy: number, ro: number, ri: number): { any }
	local pts = {}
	for i = 0, 9 do
		local a = (i / 10) * 2 * pi - pi / 2
		local r = if i % 2 == 0 then ro else ri
		table.insert(pts, cx + cos(a) * r)
		table.insert(pts, cy + sin(a) * r)
	end
	return poly(pts)
end

I.reload = {
	{ "arc", 32, 32, 20, 40, 320, 7 },
	poly({ 40, 10, 58, 20, 36, 28 }),
}

I.star = { star(32, 33, 28, 12) }

I.clock = {
	{ "ring", 32, 32, 25, 7 },
	{ "line", 32, 32, 32, 16, 6 },
	{ "line", 32, 32, 44, 38, 6 },
}

I.close = { { "line", 14, 14, 50, 50, 8 }, { "line", 50, 14, 14, 50, 8 } }

I.check = { { "line", 12, 34, 26, 48, 8 }, { "line", 26, 48, 52, 16, 8 } }

I.chevron = { { "line", 22, 10, 44, 32, 8 }, { "line", 44, 32, 22, 54, 8 } }

I.exit = {
	{ "line", 14, 10, 14, 54, 6.5 },
	{ "line", 14, 10, 36, 10, 6.5 },
	{ "line", 14, 54, 36, 54, 6.5 },
	{ "line", 26, 32, 52, 32, 6.5 },
	poly({ 46, 20, 62, 32, 46, 44 }),
}

do
	local lens = {}
	for i = 0, 15 do
		local t = i / 15
		local x = 4 + 56 * t
		local y = 32 - 20 * sin(pi * t)
		table.insert(lens, x)
		table.insert(lens, y)
	end
	for i = 15, 0, -1 do
		local t = i / 15
		local x = 4 + 56 * t
		local y = 32 + 20 * sin(pi * t)
		table.insert(lens, x)
		table.insert(lens, y)
	end
	I.eye = { poly(lens), { "erase", { "circle", 32, 32, 10 } }, { "circle", 32, 32, 5 } }
end

I.help = {
	{ "arc", 32, 24, 12, 180, 70, 8 },
	{ "line", 40, 32, 32, 42, 8 },
	{ "line", 32, 42, 32, 46, 8 },
	{ "circle", 32, 57, 4.5 },
}

I.info = {
	{ "circle", 32, 32, 28 },
	{ "erase", { "circle", 32, 18, 4.5 } },
	{ "erase", { "line", 32, 28, 32, 46, 8 } },
}

--- A folded map (the map's own options).
I.layers = {
	poly({ 4, 14, 23, 7, 41, 14, 60, 7, 60, 50, 41, 57, 23, 50, 4, 57 }),
	{ "erase", { "line", 23, 7, 23, 50, 3.5 } },
	{ "erase", { "line", 41, 14, 41, 57, 3.5 } },
}

I.music_on = {
	{ "circle", 20, 48, 9 },
	{ "line", 28, 46, 28, 12, 6 },
	poly({ 28, 12, 52, 20, 52, 30, 28, 24 }),
}

I.music_off = {
	{ "circle", 20, 48, 9 },
	{ "line", 28, 46, 28, 12, 6 },
	poly({ 28, 12, 52, 20, 52, 30, 28, 24 }),
	{ "erase", { "line", 8, 8, 56, 56, 13 } },
	{ "line", 8, 8, 56, 56, 6 },
}

I.play = { poly({ 16, 8, 56, 32, 16, 56 }) }

I.retreat = {
	{ "arc", 36, 36, 18, 270, 90, 7 },
	{ "line", 36, 18, 14, 18, 7 },
	poly({ 14, 6, 14, 30, -2, 18 }),
}

I.skull = {
	{ "circle", 32, 28, 22 },
	{ "box", 20, 40, 44, 58, 4 },
	{ "erase", { "circle", 23, 30, 6.5 } },
	{ "erase", { "circle", 41, 30, 6.5 } },
	{ "erase", poly({ 32, 35, 28, 44, 36, 44 }) },
	{ "erase", { "box", 28, 50, 29.5, 58 } },
	{ "erase", { "box", 34.5, 50, 36, 58 } },
}

I.github = {
	{ "line", 22, 14, 6, 32, 7 },
	{ "line", 6, 32, 22, 50, 7 },
	{ "line", 42, 14, 58, 32, 7 },
	{ "line", 58, 32, 42, 50, 7 },
	{ "line", 36, 10, 28, 54, 6 },
}

I.calm = {
	{ "ring", 32, 32, 26, 6 },
	{ "line", 32, 6, 32, 58, 6 },
	{ "line", 32, 32, 14, 50, 6 },
	{ "line", 32, 32, 50, 50, 6 },
}

I.crate = {
	{ "box", 6, 14, 58, 54, 3 },
	{ "erase", { "line", 12, 20, 52, 48, 4.5 } },
	{ "erase", { "line", 52, 20, 12, 48, 4.5 } },
	{ "erase", { "box", 6, 31, 12, 37 } },
}

--- Match log: lines of text, their right ends ragged (no bullets: not the Standings).
I.log = {
	{ "box", 4, 6, 60, 14, 3 },
	{ "box", 4, 20, 46, 28, 3 },
	{ "box", 4, 34, 54, 42, 3 },
	{ "box", 4, 48, 36, 56, 3 },
}

--- The game's mark: the banner of the store icon, with its W.
I.app_icon = {
	{ "box", 4, 2, 12, 62, 3 },
	poly({ 12, 6, 62, 6, 50, 27, 62, 48, 12, 48 }),
	{ "erase", { "line", 19, 14, 25, 40, 4.5 } },
	{ "erase", { "line", 25, 40, 31, 24, 4.5 } },
	{ "erase", { "line", 31, 24, 37, 40, 4.5 } },
	{ "erase", { "line", 37, 40, 43, 14, 4.5 } },
}

--- Robux: its hexagon round a hexagonal hole.
I.robux = {
	{ "grow", outline(32, 32, 6, function() return 25 end), 4.5 },
	{ "erase", { "grow", outline(32, 32, 6, function() return 9.5 end), 3 } },
}

--- The Crown of King of the Hill, the one thing on the map the words call a crown: the crown sitting on the top of a
--- round hill, parted from it (a crown on its mound: not the War Room's crown alone).
do
	local hill = {}
	for i = 0, 20 do
		local a = pi + (i / 20) * pi
		table.insert(hill, 32 + cos(a) * 31)
		table.insert(hill, 63 + sin(a) * 23)
	end
	I.crown_hill = {
		poly(hill),
		{ "erase", { "line", 0, 41, 64, 41, 5 } },
	}
	-- the Crown's own drawing (game-icons), shrunk onto the top of the hill
	local crown = {}
	for _, c in Paths.crown do
		local pts = {}
		for i = 1, #c, 2 do
			table.insert(pts, 8 + c[i] * 0.75)
			table.insert(pts, 2 + c[i + 1] * 0.75)
		end
		table.insert(crown, pts)
	end
	table.insert(I.crown_hill, { "path", crown })
end

--- Frigate: a warship side on, bow to the right: a long hull with a raked bow, a gun turret fore and aft with its
--- barrel run out, the stepped superstructure between, a funnel aft of it (game-icons has no clean warship side
--- on; this is drawn in its manner: one bold silhouette, few cut-outs). The map's frigate sprite is this drawing.
I.warship = {
	poly({ 3, 39, 52, 39, 62, 32, 56, 51, 7, 51 }),
	poly({ 24, 40, 24, 29, 28, 29, 28, 22, 32, 22, 32, 14, 37, 14, 37, 22, 41, 22, 41, 29, 44, 29, 44, 40 }),
	poly({ 14, 40, 16, 26, 22, 26, 21, 40 }),
	{ "box", 46, 32, 55, 40, 2.5 },
	{ "line", 53, 35, 62, 31.5, 3.5 },
	{ "box", 6, 32, 14, 40, 2.5 },
	{ "line", 8, 35, 1, 31.5, 3.5 },
	{ "erase", { "line", 10, 44.5, 54, 44.5, 2.5 } },
	{ "erase", { "box", 30, 24, 39, 27, 1 } },
}

--- The game-icons.net glyphs: one filled outline each.
for name, contours in Paths do
	assert(I[name] == nil, "drawn twice: " .. name)
	I[name] = { { "path", contours } }
end

--- The category frames (Art/Frames), filled: the HUD tints one under a building's or a blow's glyph.
for kind, name in Frames.icon do
	I[name] = Frames.shape(kind, 0)
end

--- Names that are the same drawing under another key (the HUD's variants).
I.ALIASES = {
	callarms = "standard",
	hud_exit = "exit",
	hud_globe = "globe",
	hud_help = "help",
	hud_leaderboard = "leaderboard",
	hud_music_off = "music_off",
	hud_music_on = "music_on",
	hud_settings = "settings",
}

return I
