--!nonstrict
-- The map's effects and rail tiles, ours: drawn from shapes here (a strike is seen from above, as the map is) and packed as palette
-- indices (the effects) and white masks (the rails, the flag's cloth). Writes src/shared/Art/FxData.luau and
-- build/art_fx.mask (a contact sheet). Run: lune run tools/art/fx.luau
local fs = require("@lune/fs")
local Raster = require("./raster")
local Codec = require("./codec")

local pi, sin, cos = math.pi, math.sin, math.cos

-- palette index -> RGBA8 (0 = clear)
local PALETTE = {
	[1] = 0xFF1C1C22, -- soot
	[2] = 0xFF45454F, -- dark smoke
	[3] = 0xFF7A7A86, -- smoke
	[4] = 0xFFB4B4BE, -- light smoke
	[5] = 0xFF9E2418, -- red
	[6] = 0xFFE0701E, -- orange
	[7] = 0xFFFFC94A, -- yellow
	[8] = 0xFFFFF4D6, -- white hot
	[9] = 0xFFFFFFFF, -- white (tinted layers)
	[10] = 0xFFB0B0B0, -- cloth grey
	[11] = 0xFF707070, -- cloth shade
	[12] = 0xFF303030, -- pole
	[13] = 0xFF6B1A10, -- deep rust
	[14] = 0xFF2A2024, -- char
}

--- A frame canvas of palette indices.
local function canvas(w: number, h: number)
	return { w = w, h = h, p = buffer.create(w * h) }
end

--- Paints index `idx` where `shape` covers a pixel by half or more.
local function paint(c, shape, idx: number)
	local m = Raster.new(c.w, c.h)
	Raster.draw(m, shape, 1, 0, 0)
	for i = 0, c.w * c.h - 1 do
		if buffer.readu8(m.a, i) >= 128 then
			buffer.writeu8(c.p, i, idx)
		end
	end
end

local function puff(c, x, y, r, idx)
	paint(c, { "circle", x, y, r }, idx)
end

-- rows of the effects atlas (the names the layer reads). `beside`: on the row above's line, after it, so small
-- rows do not make the atlas taller
local ROWS = {
	{ name = "nuke", w = 96, h = 96, frames = 8 },
	{ name = "ring", w = 96, h = 96, frames = 1 },
	{ name = "flare", w = 96, h = 96, frames = 1, beside = true },
	{ name = "sam", w = 36, h = 36, frames = 6, beside = true },
	{ name = "flag", w = 24, h = 24, frames = 10 },
	{ name = "banner", w = 24, h = 24, frames = 10, beside = true },
	{ name = "pall", w = 24, h = 24, frames = 4, beside = true },
	{ name = "ash", w = 13, h = 13, frames = 5 },
	{ name = "ember", w = 9, h = 9, frames = 4, beside = true },
	{ name = "building", w = 13, h = 13, frames = 6, beside = true },
}

local draw = {}

--- A jagged star about (cx, cy): `points` tips at radius r, valleys at r * inner, a little off regular by `seed`.
local function star(cx, cy, r, inner, points, seed)
	local pts = { "poly" }
	for i = 0, points * 2 - 1 do
		local a = i / (points * 2) * 2 * pi + sin(seed + i * 1.7) * 0.05
		local rr = if i % 2 == 0 then r * (0.86 + 0.14 * sin(seed * 2.3 + i * 2.9)) else r * inner
		table.insert(pts, cx + cos(a) * rr)
		table.insert(pts, cy + sin(a) * rr)
	end
	return pts
end

--- The blast from above, 96 px, frame f of 8: a pin of light, a star, the burst, and the rim opening round a
--- black crater, breaking into ash.
function draw.nuke(c, f)
	local C = 48
	if f == 0 then
		paint(c, star(C, C, 15, 0.16, 4, 1), 7)
		paint(c, star(C, C, 11, 0.2, 4, 1), 8)
	elseif f == 1 then
		paint(c, star(C, C, 30, 0.3, 8, 2), 6)
		paint(c, star(C, C, 23, 0.34, 8, 2), 7)
		paint(c, { "circle", C, C, 8 }, 8)
	elseif f == 2 then
		paint(c, star(C, C, 42, 0.5, 11, 3), 5)
		paint(c, star(C, C, 35, 0.52, 11, 3), 6)
		paint(c, star(C, C, 25, 0.56, 9, 4), 7)
		paint(c, { "circle", C, C, 12 }, 8)
	else
		-- the rim opens: t 0 at frame 3, 1 at frame 7
		local t = (f - 3) / 4
		local r = 38 + t * 5
		local hole = 10 + t * 26
		local rimcol = if f < 5 then 5 elseif f < 6 then 13 else 2
		paint(c, star(C, C, r, 0.78, 13, 5 + f * 0.2), rimcol)
		if f < 6 then
			paint(c, star(C, C, r - 6, 0.8, 13, 5.5 + f * 0.2), if f < 5 then 6 else 5)
		end
		if f < 5 then
			paint(c, star(C, C, r - 13, 0.8, 11, 6 + f * 0.2), 7)
		end
		-- the crater: char with a soot core, growing
		paint(c, { "circle", C, C, hole + 3 }, 14)
		paint(c, { "circle", C, C, hole * 0.62 }, 1)
		-- ash lumps breaking off the rim
		if f >= 5 then
			for i = 0, 8 do
				local a = i / 9 * 2 * pi + f * 0.11
				local rr = r + 1 - (f - 5) * 2
				puff(c, C + cos(a) * rr, C + sin(a) * rr, 5.2 - (f - 5) * 1.2, if f == 7 then 2 else 3)
			end
		end
		-- the last frame: the rim gone but for the lumps
		if f == 7 then
			paint(c, { "circle", C, C, r - 6 }, 14)
			paint(c, { "circle", C, C, hole * 0.62 }, 1)
		end
	end
end

--- The shock ring: white (the layer tints it), a thin ring broken into uneven arcs, with chips off it.
function draw.ring(c, _f)
	local C = 48
	local a0 = 0
	for i = 0, 8 do
		local len = 26 + 11 * sin(i * 2.1) ^ 2
		paint(c, { "arc", C, C, 44 - (i % 2) * 1.2, a0, a0 + len, 2.4 }, 9)
		a0 += 40
	end
end

--- The flare: a thin four-point cross of light with a smaller one turned 45 degrees (white, tinted).
function draw.flare(c, _f)
	local C = 48
	paint(c, star(C, C, 47, 0.05, 4, 0), 9)
	local diag = { "poly" }
	for i = 0, 7 do
		local a = i / 8 * 2 * pi + pi / 4
		local rr = if i % 2 == 0 then 22 else 2.4
		table.insert(diag, C + cos(a) * rr)
		table.insert(diag, C + sin(a) * rr)
	end
	paint(c, diag, 9)
	paint(c, { "circle", C, C, 7 }, 9)
end

function draw.flag(c, f)
	local ph = f / 10 * 2 * pi
	paint(c, { "line", 3, 2, 3, 22, 1.6 }, 9)
	local top, bot = {}, {}
	for i = 0, 9 do
		local x = 4 + i * 1.8
		local wave = sin(ph + i * 0.7) * 1.6
		table.insert(top, x)
		table.insert(top, 3 + wave)
		table.insert(bot, x)
		table.insert(bot, 13 + wave)
	end
	local pts = { "poly" }
	for i = 1, #top do
		table.insert(pts, top[i])
	end
	for i = #bot - 1, 1, -2 do
		table.insert(pts, bot[i])
		table.insert(pts, bot[i + 1])
	end
	paint(c, pts, 9)
end

function draw.banner(c, f)
	local ph = f / 10 * 2 * pi
	paint(c, { "line", 3, 2, 3, 22, 1.6 }, 12)
	local pts = { "poly" }
	local lo = {}
	for i = 0, 9 do
		local x = 4 + i * 1.8
		local wave = sin(ph + i * 0.7) * 1.6
		table.insert(pts, x)
		table.insert(pts, 3 + wave)
		table.insert(lo, x)
		table.insert(lo, 13 + wave)
	end
	for i = #lo - 1, 1, -2 do
		table.insert(pts, lo[i])
		table.insert(pts, lo[i + 1])
	end
	paint(c, pts, 10)
	-- the cloth's shade, a fold that travels
	local fx = 4 + ((f % 10) / 10) * 16
	paint(c, { "box", fx, 3, fx + 3, 13, 0 }, 11)
end

--- A warhead stopped in the air, from above: a spark that scatters.
function draw.sam(c, f)
	local C = 18
	local t = f / 5
	paint(c, star(C, C, 6 + t * 9, 0.42, 7, 7), if f < 2 then 7 elseif f < 4 then 6 else 3)
	if f < 3 then
		paint(c, { "circle", C, C, 4 - f }, 8)
	end
	if f >= 2 then
		paint(c, { "circle", C, C, 2 + t * 8 }, 0)
	end
	for i = 0, 6 do
		local a = i / 7 * 2 * pi + 0.4
		local rr = 7 + t * 10
		puff(c, C + cos(a) * rr, C + sin(a) * rr, 1.5 - t * 0.7, if f < 3 then 7 else 4)
	end
end

--- A building blown apart, from above: a dark star and its pieces flying off.
function draw.building(c, f)
	local C = 6.5
	local t = f / 5
	paint(c, star(C, C, 2.6 + t * 2.4, 0.5, 5, 3), if f < 2 then 6 else 2)
	for i = 0, 4 do
		local a = i / 5 * 2 * pi + 0.9
		local rr = 2 + t * 4
		puff(c, C + cos(a) * rr, C + sin(a) * rr, 0.9, if f < 3 then 3 else 4)
	end
end

--- Embers on the burnt ground: a few bright specks that swell and dim in turn.
function draw.ember(c, f)
	local C = 4.5
	local SPOTS = { { -1.8, -1.2 }, { 1.6, -1.8 }, { 0.2, 1.6 }, { -2.2, 2 } }
	for i, sp in SPOTS do
		local on = (f + i) % 4
		local col = if on == 0 then 7 elseif on == 1 then 6 else 5
		paint(c, { "circle", C + sp[1], C + sp[2], if on == 0 then 1.25 else 0.9 }, col)
	end
end

--- Ash blowing across, from above: flecks that spread and pale.
function draw.ash(c, f)
	local C = 6.5
	local t = f / 4
	for i = 0, 5 do
		local a = i / 6 * 2 * pi + t * 0.7
		local rr = 1.6 + t * 3.8 + (i % 2) * 0.8
		puff(c, C + cos(a) * rr, C + sin(a) * rr, 1.2 - t * 0.3, if t < 0.5 then 2 else 3)
	end
end

--- A low pall of smoke, from above: a blot that turns slowly.
function draw.pall(c, f)
	local C = 12
	local ph = f / 4 * 2 * pi
	puff(c, C, C, 6, 14)
	for i = 0, 4 do
		local a = i / 5 * 2 * pi + ph * 0.25
		local rr = 5.5 + sin(ph + i) * 0.8
		puff(c, C + cos(a) * rr, C + sin(a) * rr, 3.8, 2)
	end
	puff(c, C + cos(ph) * 2, C + sin(ph) * 2, 2.6, 3)
end

local width = 0
local height = 0
do
	local x, line = 0, 0
	for _, r in ROWS do
		if not r.beside then
			height += line
			x, line = 0, 0
		end
		r.x, r.y = x, height
		x += r.w * r.frames
		line = math.max(line, r.h)
		width = math.max(width, x)
	end
	height += line
end
local atlas = Raster.new(width, height) -- palette indices as bytes
local sheet = Raster.new(width * 3, height * 3 + 8)
for _, r in ROWS do
	for f = 0, r.frames - 1 do
		local c = canvas(r.w, r.h)
		draw[r.name](c, f)
		for y = 0, r.h - 1 do
			for x = 0, r.w - 1 do
				local idx = buffer.readu8(c.p, y * r.w + x)
				buffer.writeu8(atlas.a, (r.y + y) * width + r.x + f * r.w + x, idx)
			end
		end
	end
end
-- contact sheet: palette colours (grey ramp of the RGB) at 3x
for y = 0, height - 1 do
	for x = 0, width - 1 do
		local idx = buffer.readu8(atlas.a, y * width + x)
		local col = PALETTE[idx]
		local v = 0
		if col ~= nil then
			local rr, gg, bb = col % 256, (col // 256) % 256, (col // 65536) % 256
			v = math.floor((rr + gg + bb) / 3)
		end
		for dy = 0, 2 do
			for dx = 0, 2 do
				buffer.writeu8(sheet.a, (y * 3 + dy) * sheet.w + x * 3 + dx, v)
			end
		end
	end
end
local head = buffer.create(8)
buffer.writeu32(head, 0, sheet.w)
buffer.writeu32(head, 4, sheet.h)
fs.writeFile("build/art_fx.mask", buffer.tostring(head) .. buffer.tostring(sheet.a))

-- rail tiles: 16 x 16 white masks. h / v straight, tl tr bl br the four bends (centre at that corner)
local T = 16
local function rail(name: string)
	local m = Raster.new(T, T)
	local function item(i)
		Raster.draw(m, i, 1, 0, 0)
	end
	if name == "h" then
		item({ "box", 0, 4, T, 5.6, 0 })
		item({ "box", 0, 10.4, T, 12, 0 })
		for x = 1, T - 1, 4 do
			item({ "box", x, 2.5, x + 1.6, 13.5, 0 })
		end
	elseif name == "v" then
		item({ "box", 4, 0, 5.6, T, 0 })
		item({ "box", 10.4, 0, 12, T, 0 })
		for y = 1, T - 1, 4 do
			item({ "box", 2.5, y, 13.5, y + 1.6, 0 })
		end
	else
		local cx = if name == "tl" or name == "bl" then 0 else T
		local cy = if name == "tl" or name == "tr" then 0 else T
		local a0 = ({ tl = 0, tr = 90, bl = 270, br = 180 })[name]
		item({ "arc", cx, cy, 5, a0, a0 + 90, 1.6 })
		item({ "arc", cx, cy, 11, a0, a0 + 90, 1.6 })
		for k = 0, 4 do
			local a = (a0 + 8 + k * 18.5) * pi / 180
			item({ "line", cx + cos(a) * 3.4, cy + sin(a) * 3.4, cx + cos(a) * 12.6, cy + sin(a) * 12.6, 1.6 })
		end
	end
	return m
end

local out = {
	"-- GENERATED by tools/art/fx.luau: do not edit by hand.",
	"-- The map's effects (palette indices, one atlas laid out as the layer reads it) and rail tiles (white masks), ours.",
	"return {",
	"\tpalette = {",
}
for i = 1, #PALETTE do
	table.insert(out, string.format("\t\t[%d] = 0x%08X,", i, PALETTE[i]))
end
table.insert(out, "\t},")
table.insert(out, "\trows = {")
for _, r in ROWS do
	table.insert(out, string.format("\t\t%s = { x = %d, y = %d, w = %d, h = %d, frames = %d },", r.name, r.x, r.y, r.w, r.h, r.frames))
end
table.insert(out, "\t},")
table.insert(out, string.format("\tatlas = { w = %d, h = %d, data = \"%s\" },", width, height, Codec.b64(Codec.rle(atlas))))
table.insert(out, "\trails = {")
for _, name in { "h", "v", "tl", "tr", "bl", "br" } do
	table.insert(out, string.format("\t\t%s = { w = %d, h = %d, data = \"%s\" },", name, T, T, Codec.b64(Codec.rle(rail(name)))))
end
table.insert(out, "\t},")
table.insert(out, "}")
fs.writeFile("src/shared/Art/FxData.luau", table.concat(out, "\n") .. "\n")
print("fx packed", width, height)
