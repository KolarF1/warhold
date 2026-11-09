--!strict
-- The map's art, ours: structure plates (a silhouette per kind, a rim and an inset), glyphs, and the units'
-- sprites in 32 px cells (pointing right; the layer rotates them). Writes src/shared/Art/MapData.luau (packed
-- masks) and build/art_map.mask (a contact sheet for tools/art/mask_to_png.py).
-- Run: lune run tools/art/mapart.luau
local fs = require("@lune/fs")
local Raster = require("./raster")
local Icons = require("./icons")
local Pack = require("./codec")
local Frames = require("../../src/shared/Art/Frames")

-- structure kinds in Defs.S_* order
local KINDS = { "city", "port", "factory", "defense", "sam", "silo", "artillery", "airfield", "railgun", "farm", "market", "barracks", "fort" }
local CELL = 112

-- The plates: each kind's category frame (Art/Frames: a square for the economy, a shield for defence, a diamond for a
-- strike), the icons' 64-unit grid filling the 112 px cell. The layer sizes the cell (StructureLayer.ICON_SIZE x
-- MapArt.shape_scale) and lays the glyph over the middle (MapArt.icon_fill). The rim is RIM units of the grid: about
-- 2 px at the normal zoom, dark enough and wide enough to part a plate from land of its own colour.
local GRID = CELL / 64
local RIM = 5

-- (one plate a frame, shared by the kinds that wear it: 13 kinds at 112 px each passed the 1024 px an EditableImage
-- may be wide, 2026-11-09; `plate_col` maps a kind to its frame's cell)
local FRAMES = {}
local PLATE_COL = {}
for k, name in KINDS do
	local frame = Frames.of[name]
	assert(frame, "no frame for " .. name)
	local at = table.find(FRAMES, frame)
	if at == nil then
		table.insert(FRAMES, frame)
		at = #FRAMES
	end
	PLATE_COL[k] = at - 1
end
local rim = Raster.new(CELL * #FRAMES, CELL)
local inset = Raster.new(CELL * #FRAMES, CELL)
for f, frame in FRAMES do
	local r = Raster.new(CELL, CELL)
	for _, item in Frames.shape(frame, 0) do
		Raster.draw(r, item, GRID, 0, 0)
	end
	Raster.blit(rim, r, (f - 1) * CELL, 0)
	local i = Raster.new(CELL, CELL)
	for _, item in Frames.shape(frame, RIM) do
		Raster.draw(i, item, GRID, 0, 0)
	end
	Raster.blit(inset, i, (f - 1) * CELL, 0)
end

-- glyphs: the structure icons, 64 px, one strip
local GL = 64
local glyphs = Raster.new(GL * #KINDS, GL)
for k, name in KINDS do
	Raster.blit(glyphs, Raster.render(Icons[name], GL, GL, 64), (k - 1) * GL, 0)
end
-- the medieval start dates' strip (Data/PeriodTech: a Town, a Smithy, a Castle...), the same kinds in the same order;
-- a kind with no medieval drawing keeps its own (2026-11-08, the owner: the map's buildings were still today's)
local glyphs_m = Raster.new(GL * #KINDS, GL)
for k, name in KINDS do
	local icon = Icons["m_" .. name] or Icons[name]
	Raster.blit(glyphs_m, Raster.render(icon, GL, GL, 64), (k - 1) * GL, 0)
end

-- units, pointing right (the layer rotates them), one 32 px cell each: transport, trade, warship, atom, hydrogen, mirv,
-- sam, shell, warhead, train, carriage, carriage_loaded
local UC = 48 -- px a cell: above the largest a sprite is drawn (UnitLayer.MAX_PX), so a sharp screen never stretches it

-- The ships and the munitions. Ships are seen side on, as their glyphs are (2026-11-07, the owner: clearer, in the style
-- of the rest of the art): a landing is a longship, a trader a cargo ship, a frigate the Frigate glyph; they never turn,
-- they face the way they sail (a mirrored cell, `<name>_w`, for going west). The munitions fly nose first (the layer
-- turns them): a Warhead and a Cluster's warhead are a finned missile, a Great Warhead the bomb with the trefoil, a
-- Cluster Warhead three of the missile flying together, Flak the missile. Outlines from game-icons.net (tools/art/gi_units.json,
-- CC BY 3.0); a shell is ours, a bright slug with its tracer fading out behind it (STREAK).
-- Each is a body in its owner's colour with a dark rim RIM_PX wide round it (the body spread by the rim), like the
-- buildings' plates; a hole in it narrower than two rims fills with the rim, so its inner lines read as ink.
-- Everything stays INSET units inside the cell, so the rim is never cut off.
local RIM_PX = 4 -- cell px: about 2 px at the normal zoom
local INSET = 6 -- grid units kept clear round a sprite for its rim
local GIU = require("./gi_units")
local function outline(name: string): { any }
	return { { "path", GIU[name] } }
end
local SOURCES = {
	-- (2026-11-09, the owner: today's art more modern) a landing craft: a low hull, its bow ramp raised, the wheelhouse aft
	transport = {
		{ "poly", 3, 34, 50, 34, 58, 38, 58, 47, 52, 51, 7, 51, 3, 46 },
		{ "poly", 50, 34, 55, 20, 60, 22, 58, 38 },
		{ "box", 5, 20, 19, 34, 2 },
		{ "box", 9, 12, 15, 20, 1 },
		{ "line", 12, 5, 12, 12, 2 },
		{ "erase", { "box", 8, 23, 16, 27, 1 } },
		{ "erase", { "line", 22, 40, 48, 40, 2.5 } },
	},
	trade = outline("trade"),
	warship = Icons.warship,
	atom = outline("atom"),
	hydrogen = outline("hydrogen"),
	mirv = (function()
		-- (three of the Warhead's missile, small and apart: a swarm of five ran into one blob at sprite size)
		local out = {}
		for _, at in { { 0.5, 18, 6 }, { 0.5, 18, 34 }, { 0.5, 34, 20 } } do
			local k, dx, dy = at[1], at[2], at[3]
			local cs = {}
			for _, c in GIU.atom do
				local pts = {}
				for i = 1, #c, 2 do
					table.insert(pts, dx + c[i] * k)
					table.insert(pts, dy + c[i + 1] * k)
				end
				table.insert(cs, pts)
			end
			table.insert(out, { "path", cs })
		end
		return out
	end)(),
	sam = outline("sam"),
	warhead = outline("warhead"),
	-- the medieval start dates' (Data/PeriodTech): a galley of war, a merchant longship, a pot of Greek fire, the
	-- bombard's stone, the plague catapult's carcass and its shards
	m_warship = Icons.m_galley,
	-- (2026-11-09, the owner: a landing and a trader looked alike) the longship lands raiders; a trader is a sailing
	-- merchantman with castles fore and aft
	m_transport = outline("transport"),
	-- (a cog, ours: the merchantman of 1100-1400 and the nearest to every date here; a caravel is 15th-century)
	m_trade = {
		{ "poly", 3, 38, 61, 38, 55, 50, 46, 54, 16, 54, 8, 50 },
		{ "box", 3, 28, 17, 38, 1.5 },
		{ "box", 49, 30, 61, 38, 1.5 },
		{ "line", 33, 5, 33, 38, 3 },
		{ "poly", 19, 9, 47, 9, 50, 19, 47, 29, 19, 29, 16, 19 },
		{ "erase", { "line", 20, 19, 46, 19, 2 } },
		{ "poly", 33, 3, 43, 5.5, 33, 8 },
		{ "erase", { "line", 6, 44, 58, 44, 2 } },
	},
	-- the medieval wagon train in place of the truck: a covered wagon leads, open carts follow (sacks on them when full)
	m_train = outline("m_train"),
	m_carriage = {
		{ "box", 4, 20, 56, 32, 2 },
		{ "erase", { "line", 6, 26, 54, 26, 2 } },
		{ "line", 56, 27, 63, 25, 2.5 },
		{ "circle", 30, 42, 13 },
		{ "erase", { "circle", 30, 42, 9.5 } },
		{ "line", 30, 31, 30, 53, 2 },
		{ "line", 19, 42, 41, 42, 2 },
		{ "line", 22.5, 34.5, 37.5, 49.5, 2 },
		{ "line", 22.5, 49.5, 37.5, 34.5, 2 },
		{ "circle", 30, 42, 3.5 },
	},
	m_carriage_loaded = {
		{ "box", 4, 26, 56, 36, 2 },
		{ "erase", { "line", 6, 31, 54, 31, 2 } },
		{ "box", 7, 10, 25, 26, 6 },
		{ "box", 27, 8, 45, 26, 6 },
		{ "box", 44, 14, 55, 26, 4 },
		{ "line", 56, 31, 63, 29, 2.5 },
		{ "circle", 30, 45, 12 },
		{ "erase", { "circle", 30, 45, 8.5 } },
		{ "line", 30, 35, 30, 55, 2 },
		{ "line", 20, 45, 40, 45, 2 },
		{ "line", 23, 38, 37, 52, 2 },
		{ "line", 23, 52, 37, 38, 2 },
		{ "circle", 30, 45, 3.5 },
	},
	m_atom = Icons.m_atom,
	m_hydrogen = { { "circle", 32, 32, 16 } },
	m_mirv = Icons.m_mirv,
	m_warhead = Icons.m_mirv,
	shell = {
		{ "circle", 34, 32, 7.5 },
		{ "poly", 34, 24.5, 43, 26.5, 50, 32, 43, 37.5, 34, 39.5 },
	},
	-- a truck and its trailers, side on, facing the way they drive: the cab game-icons', the trailers ours in its manner
	-- (a box on two wheels, two crates on it when full)
	train = outline("train"),
	carriage = {
		{ "box", 4, 22, 60, 46, 3 },
		{ "erase", { "line", 4, 40, 60, 40, 2.5 } },
		{ "circle", 16, 48, 7 },
		{ "circle", 48, 48, 7 },
		{ "erase", { "circle", 16, 48, 2.5 } },
		{ "erase", { "circle", 48, 48, 2.5 } },
	},
	carriage_loaded = {
		{ "box", 4, 28, 60, 46, 3 },
		{ "box", 8, 13, 30, 29, 2 },
		{ "box", 34, 13, 56, 29, 2 },
		{ "erase", { "line", 4, 40, 60, 40, 2.5 } },
		{ "circle", 16, 48, 7 },
		{ "circle", 48, 48, 7 },
		{ "erase", { "circle", 16, 48, 2.5 } },
		{ "erase", { "circle", 48, 48, 2.5 } },
	},
}
--- The ships and the truck's cars, which face the way they go: each also gets a mirrored cell, `<name>_w`.
local SHIPS = { "transport", "trade", "warship" }
--- A sprite's streak: a body drawn with no rim under its rimmed body, its cover ramping from nothing at its tail (grid
--- x `from`) to full (`to`). The shell's tracer: a long taper behind the slug.
local STREAK = { shell = { from = -10, to = 26, shape = { "poly", 34, 25, 34, 39, 1, 33.8, 1, 30.2 } } }

local UNIT_ORDER = { "transport", "trade", "warship", "atom", "hydrogen", "mirv", "sam", "shell", "warhead", "train", "carriage", "carriage_loaded", "transport_w", "trade_w", "warship_w", "train_w", "carriage_w", "carriage_loaded_w",
	-- (after the rest, so today's columns never move: UnitLayer.MEDIEVAL_COL maps onto these)
	"m_trade", "m_warship", "m_atom", "m_hydrogen", "m_mirv", "m_warhead", "m_trade_w", "m_warship_w",
	-- (2026-11-09: the medieval landing and wagon train, after the rest again, with their west cells)
	"m_transport", "m_train", "m_carriage", "m_carriage_loaded", "m_transport_w", "m_train_w", "m_carriage_w", "m_carriage_loaded_w" }
--- The outline of mask `m` against `spread` (the same coverage spread outwards): what `spread` covers beyond `m`.
local function less(spread: Raster.Mask, m: Raster.Mask): Raster.Mask
	local o = Raster.new(m.w, m.h)
	for i = 0, m.w * m.h - 1 do
		buffer.writeu8(o.a, i, math.max(0, buffer.readu8(spread.a, i) - buffer.readu8(m.a, i)))
	end
	return o
end

--- Scales `m`'s cover along x: nothing left of grid unit `x0`, full right of `x1`, a ramp between.
local function fade(m: Raster.Mask, x0: number, x1: number)
	for y = 0, m.h - 1 do
		for x = 0, m.w - 1 do
			local u = (x + 0.5) * 64 / UC
			local f = math.clamp((u - x0) / (x1 - x0), 0, 1)
			local i = y * m.w + x
			buffer.writeu8(m.a, i, math.floor(buffer.readu8(m.a, i) * f + 0.5))
		end
	end
end

--- `m` spread `r` px all round (a disc's most): the body and its rim together.
local function dilate(m: Raster.Mask, r: number): Raster.Mask
	local o = Raster.new(m.w, m.h)
	local offs = {}
	for dy = -r, r do
		for dx = -r, r do
			if dx * dx + dy * dy <= r * r + r then
				table.insert(offs, { dx, dy })
			end
		end
	end
	for y = 0, m.h - 1 do
		for x = 0, m.w - 1 do
			local best = 0
			for _, d in offs do
				local sx, sy = x + d[1], y + d[2]
				if sx >= 0 and sy >= 0 and sx < m.w and sy < m.h then
					local v = buffer.readu8(m.a, sy * m.w + sx)
					if v > best then
						best = v
					end
				end
			end
			buffer.writeu8(o.a, y * m.w + x, best)
		end
	end
	return o
end

--- `m` mirrored left to right.
local function mirror(m: Raster.Mask): Raster.Mask
	local o = Raster.new(m.w, m.h)
	for y = 0, m.h - 1 do
		for x = 0, m.w - 1 do
			buffer.writeu8(o.a, y * m.w + (m.w - 1 - x), buffer.readu8(m.a, y * m.w + x))
		end
	end
	return o
end

local body = Raster.new(UC * #UNIT_ORDER, UC)
local rimu = Raster.new(UC * #UNIT_ORDER, UC)
local made: { [string]: { Raster.Mask } } = {}
for k, name in UNIT_ORDER do
	local m, o
	local base = string.match(name, "^(.-)_w$")
	if base ~= nil and made[base] ~= nil then
		m, o = mirror(made[base][1]), mirror(made[base][2])
	else
		m = Raster.new(UC, UC)
		local shape = SOURCES[name]
		assert(shape, "no drawing for unit sprite " .. name)
		-- the 64-unit drawing inset INSET units all round, then the rim round the whole of it
		local sc = (UC / 64) * (64 - 2 * INSET) / 64
		for _, item in shape do
			Raster.draw(m, item, sc, INSET * UC / 64, INSET * UC / 64)
		end
		o = less(dilate(m, RIM_PX), m)
		local streak = STREAK[name]
		if streak then
			local t = Raster.new(UC, UC)
			Raster.draw(t, streak.shape, UC / 64, 0, 0)
			fade(t, streak.from, streak.to)
			for i = 0, UC * UC - 1 do
				-- (under the rim: it shows only where the rim does not)
				local under = math.floor(buffer.readu8(t.a, i) * (1 - buffer.readu8(o.a, i) / 255) + 0.5)
				buffer.writeu8(m.a, i, math.max(buffer.readu8(m.a, i), under))
			end
		end
		made[name] = { m, o }
	end
	Raster.blit(body, m, (k - 1) * UC, 0)
	Raster.blit(rimu, o, (k - 1) * UC, 0)
end
assert(#SHIPS == 3, "three ships face their way")

-- the data module
local function entry(name: string, m: Raster.Mask): string
	return string.format("\t%s = { w = %d, h = %d, data = \"%s\" },", name, m.w, m.h, Pack.b64(Pack.rle(m)))
end
local out = {
	"-- GENERATED by tools/art/mapart.luau: do not edit by hand.",
	"-- The map's art, ours: run-length coverage masks in base64 (Art/Pack decodes them).",
	"return {",
	"\tkinds = { " .. (function()
		local t = {}
		for _, k in KINDS do
			table.insert(t, '"' .. k .. '"')
		end
		return table.concat(t, ", ")
	end)() .. " },",
	"\tunit_names = { " .. (function()
		local t = {}
		for _, k in UNIT_ORDER do
			table.insert(t, '"' .. k .. '"')
		end
		return table.concat(t, ", ")
	end)() .. " },",
	"	plate_col = { " .. (function()
		local t = {}
		for _, c in PLATE_COL do
			table.insert(t, tostring(c))
		end
		return table.concat(t, ", ")
	end)() .. " },",
	entry("plate_rim", rim),
	entry("plate_inset", inset),
	entry("glyphs", glyphs),
	entry("glyphs_m", glyphs_m),
	entry("unit_body", body),
	entry("unit_rim", rimu),
	"}",
}
fs.writeFile("src/shared/Art/MapData.luau", table.concat(out, "\n") .. "\n")

-- contact sheet: plates with glyphs over them in a few colours, and the units enlarged 8x
local cols = { 255, 190, 120 }
local sheet = Raster.new(UC * 3 * #UNIT_ORDER + 16, CELL * 3 + 16 + UC * 3 + 24)
for row = 1, 3 do
	for k = 1, #KINDS do
		local x0 = 8 + (k - 1) * CELL
		local y0 = 8 + (row - 1) * CELL
		for y = 0, CELL - 1 do
			for x = 0, CELL - 1 do
				local r = buffer.readu8(rim.a, y * rim.w + PLATE_COL[k] * CELL + x)
				local i = buffer.readu8(inset.a, y * inset.w + PLATE_COL[k] * CELL + x)
				local v = math.max(r // 3, i * cols[row] // 255)
				local gx, gy = x - 24, y - 24
				local gv = 0
				if gx >= 0 and gy >= 0 and gx < 64 and gy < 64 then
					gv = buffer.readu8(glyphs.a, gy * glyphs.w + (k - 1) * GL + gx)
				end
				local val = if gv > 0 then math.max(0, v - gv // 2) else v
				buffer.writeu8(sheet.a, (y0 + y) * sheet.w + x0 + x, val)
			end
		end
	end
end
for k = 1, #UNIT_ORDER do
	for y = 0, UC - 1 do
		for x = 0, UC - 1 do
			local b = buffer.readu8(body.a, y * body.w + (k - 1) * UC + x)
			local r = buffer.readu8(rimu.a, y * rimu.w + (k - 1) * UC + x)
			local v = math.max(b, r // 2)
			for dy = 0, 2 do
				for dx = 0, 2 do
					local px, py = 8 + (k - 1) * UC * 3 + x * 3 + dx, 8 + CELL * 3 + 8 + y * 3 + dy
					if px < sheet.w then
						buffer.writeu8(sheet.a, py * sheet.w + px, v)
					end
				end
			end
		end
	end
end
local head = buffer.create(8)
buffer.writeu32(head, 0, sheet.w)
buffer.writeu32(head, 4, sheet.h)
fs.writeFile("build/art_map.mask", buffer.tostring(head) .. buffer.tostring(sheet.a))
print("map art packed")
