--!strict
-- The Standards' pictures, one per Standard (Assets/ShopFlags, by key; the key stays even when the name moved on, because
-- saves hold it): a field and its colours, and a charge on a 64 x 64 grid (the shape lists of tools/art/raster.luau),
-- packed by tools/art/pack.luau into src/shared/Art/StandardData.luau. Art/Emblem paints them.
--
-- Each rarity is richer than the one below. Honoured: a plain field, a charge in one colour. Storied: a patterned field, a
-- charge in two colours. Mythic: a sunburst field, two colours and a halo. (The frames are Emblem's; Issued is the country
-- flags, Emblem's hash.)
--   field   plain, pale (split down), fess (split across), bend (split aslant), chief (a band on top)      Honoured
--           check, lozenge, chevron, paly, wave, saltire                                                   Storied
--           rays                                                                                           Mythic
--   c       { field, field's second colour, main, accent }
--   main    the charge. erase cuts through to the field.
--   accent  drawn over main, in the fourth colour (erase here shows main)
local S = {}

local pi, cos, sin = math.pi, math.cos, math.sin

local function poly(pts: { number }): { any }
	local out: { any } = { "poly" }
	for _, v in pts do
		table.insert(out, v)
	end
	return out
end

--- A star of `n` points, the first straight up.
local function star(cx: number, cy: number, ro: number, ri: number, n: number): { any }
	local pts = {}
	for i = 0, n * 2 - 1 do
		local a = (i / (n * 2)) * 2 * pi - pi / 2
		local r = if i % 2 == 0 then ro else ri
		table.insert(pts, cx + cos(a) * r)
		table.insert(pts, cy + sin(a) * r)
	end
	return poly(pts)
end

--- A line through `pts` thinning from w0 to w1 (a snake's neck).
local function taper(pts: { number }, w0: number, w1: number): { any }
	local out = {}
	local n = #pts // 2 - 1
	for i = 1, n do
		local w = w0 + (w1 - w0) * (i - 1) / math.max(n - 1, 1)
		table.insert(out, { "line", pts[i * 2 - 1], pts[i * 2], pts[i * 2 + 1], pts[i * 2 + 2], w })
	end
	return out
end

--- Points on an arc of an ellipse turned by `rot` (degrees) from angle a0 to a1 (degrees).
local function ellipse_pts(cx: number, cy: number, rx: number, ry: number, rot: number, a0: number, a1: number, n: number): { number }
	local out = {}
	local cr, sr = cos(rot * pi / 180), sin(rot * pi / 180)
	for i = 0, n do
		local a = (a0 + (a1 - a0) * i / n) * pi / 180
		local x, y = cos(a) * rx, sin(a) * ry
		table.insert(out, cx + x * cr - y * sr)
		table.insert(out, cy + x * sr + y * cr)
	end
	return out
end

--- A band along that ellipse (a balloon's seams, a globe's meridians).
local function ellipse_band(cx: number, cy: number, rx: number, ry: number, rot: number, a0: number, a1: number, w: number): { any }
	local outer = ellipse_pts(cx, cy, rx + w * 0.5, ry + w * 0.5, rot, a0, a1, 24)
	local inner = ellipse_pts(cx, cy, rx - w * 0.5, ry - w * 0.5, rot, a1, a0, 24)
	for _, v in inner do
		table.insert(outer, v)
	end
	return poly(outer)
end

local function cat(...: { any }): { any }
	local out = {}
	for _, list in { ... } do
		for _, item in list do
			table.insert(out, item)
		end
	end
	return out
end

--- Mirrors a poly's points across x = 32.
local function mirror(pts: { number }): { any }
	local out = {}
	for i = 1, #pts, 2 do
		table.insert(out, 64 - pts[i])
		table.insert(out, pts[i + 1])
	end
	return poly(out)
end

-- Dawn: beasts and house marks ---------------------------------------------------------------------------------------

--- Boar's Head: a boar's head in profile, its neck bristling, one tusk white.
S.cat = {
	field = "chevron",
	c = { 0x5E2A16, 0x47200F, 0xCDB48A, 0xFFF4D6 },
	main = {
		poly({ 3, 40, 6, 32, 22, 22, 30, 19, 33, 6, 41, 17, 46, 14, 48, 20, 53, 17, 54, 24, 60, 23, 58, 30, 63, 33, 59, 38, 61, 56, 50, 51, 42, 58, 33, 51, 16, 51, 5, 47 }),
		{ "erase", { "circle", 26, 29, 2.8 } },
		{ "erase", { "circle", 8, 38, 1.6 } },
		{ "erase", { "line", 6, 44, 26, 44, 2.2 } },
	},
	accent = {
		poly({ 21, 46, 9, 30, 7, 35, 10, 48 }),
	},
}
--- Mountain Ram: a ram's head, front on, horns curled.
S.capybara = {
	field = "fess",
	c = { 0x22304A, 0x161F33, 0xE4E8EE, 0 },
	main = {
		poly({ 23, 18, 41, 18, 43, 36, 37, 54, 32, 62, 27, 54, 21, 36 }),
		{ "arc", 15, 24, 11, 90, 340, 8 },
		{ "arc", 49, 24, 11, 200, 90, 8 },
		{ "circle", 15, 35, 4 },
		{ "circle", 49, 35, 4 },
		{ "erase", { "circle", 27, 33, 2.5 } },
		{ "erase", { "circle", 37, 33, 2.5 } },
		{ "erase", poly({ 28, 51, 36, 51, 32, 56 }) },
	},
}
--- Elder Oak: a great oak, its trunk and acorns gilded.
S.pizza = {
	field = "rays",
	c = { 0x1B4332, 0x0E2A20, 0x8FCB6B, 0xF4C95A },
	main = {
		{ "circle", 32, 19, 17 },
		{ "circle", 14, 27, 12 },
		{ "circle", 50, 27, 12 },
		{ "circle", 21, 12, 10 },
		{ "circle", 43, 12, 10 },
		{ "box", 10, 28, 54, 38, 5 },
	},
	accent = {
		poly({ 27, 32, 37, 32, 38, 50, 50, 62, 14, 62, 26, 50 }),
		{ "line", 29, 36, 15, 27, 3.5 },
		{ "line", 35, 36, 49, 27, 3.5 },
		{ "line", 32, 34, 32, 16, 3.5 },
		{ "circle", 20, 15, 3 },
		{ "circle", 44, 15, 3 },
		{ "circle", 9, 31, 3 },
		{ "circle", 55, 31, 3 },
	},
}
--- Sun in Splendour: the sun with a stern face, its rays all round it.
S.rubber_duck = {
	field = "rays",
	c = { 0x14295C, 0x1F3C80, 0xFFC94A, 0xFFF0B8 },
	main = {
		star(32, 32, 32, 17, 16),
	},
	accent = {
		{ "circle", 32, 32, 15 },
		{ "erase", { "line", 23, 27, 29, 28, 2.6 } },
		{ "erase", { "line", 41, 27, 35, 28, 2.6 } },
		{ "erase", { "line", 32, 28, 32, 35, 2.2 } },
		{ "erase", { "line", 27, 40, 37, 40, 2.4 } },
	},
}
--- Iron Portcullis: a castle's iron gate, its teeth down.
do
	local list: { any } = { { "box", 5, 3, 59, 11, 1.5 } }
	for _, x in { 11, 21.5, 32, 42.5, 53 } do
		table.insert(list, { "box", x - 2.8, 10, x + 2.8, 54 })
		table.insert(list, poly({ x - 2.8, 53, x + 2.8, 53, x, 63 }))
	end
	for _, y in { 20, 32, 44 } do
		table.insert(list, { "box", 7, y - 2.5, 57, y + 2.5 })
	end
	S.lion_crest = { field = "pale", c = { 0x2B5D4C, 0x1E4436, 0xE0E4E8, 0 }, main = list }
end
--- Great Stag: a stag's head under its antlers.
S.wolf_pack = {
	field = "paly",
	c = { 0x3D5A2E, 0x2F4823, 0xE8D9B0, 0xF4C95A },
	main = {
		poly({ 21, 28, 43, 28, 40, 44, 36, 60, 28, 60, 24, 44 }),
		poly({ 22, 30, 7, 24, 10, 34, 24, 38 }),
		poly({ 42, 30, 57, 24, 54, 34, 40, 38 }),
		{ "erase", { "circle", 26, 35, 2.6 } },
		{ "erase", { "circle", 38, 35, 2.6 } },
		{ "erase", poly({ 28, 53, 36, 53, 32, 58 }) },
	},
	accent = {
		{ "line", 26, 28, 14, 3, 4.5 },
		{ "line", 20, 15, 5, 13, 4 },
		{ "line", 17, 9, 27, 3, 3.5 },
		{ "line", 38, 28, 50, 3, 4.5 },
		{ "line", 44, 15, 59, 13, 4 },
		{ "line", 47, 9, 37, 3, 3.5 },
	},
}
--- Golden Bee: a bee from above, its wings spread.
do
	local upper = { 26, 22, 6, 6, 1, 18, 10, 30, 26, 29 }
	local lower = { 25, 31, 8, 33, 8, 44, 16, 46, 25, 37 }
	S.phoenix = {
		field = "bend",
		c = { 0x4A2A6B, 0x38205A, 0xF2C94A, 0 },
		main = {
			poly(upper),
			mirror(upper),
			poly(lower),
			mirror(lower),
			{ "circle", 32, 11, 6 },
			{ "circle", 32, 22, 8 },
			{ "box", 23, 29, 41, 54, 9 },
			poly({ 26, 50, 38, 50, 32, 63 }),
			{ "erase", { "box", 20, 36, 44, 39 } },
			{ "erase", { "box", 20, 45, 44, 48 } },
			{ "line", 29, 7, 23, 1, 2.6 },
			{ "line", 35, 7, 41, 1, 2.6 },
		},
	}
end
--- Harvest Sheaf: a bound sheaf of wheat.
do
	local list: { any } = {
		{ "line", 32, 60, 32, 12, 3.5 },
		{ "line", 28, 60, 16, 16, 3.5 },
		{ "line", 36, 60, 48, 16, 3.5 },
		{ "box", 20, 40, 44, 47, 2 },
	}
	local function grain(x: number, y: number, deg: number)
		local a = deg * pi / 180
		local dx, dy = cos(a), sin(a)
		table.insert(list, poly({ x + dx * 7, y + dy * 7, x - dy * 3, y + dx * 3, x - dx * 3, y - dy * 3, x + dy * 3, y - dx * 3 }))
	end
	for _, st in { { 32, 12, 0 }, { 16, 16, -16 }, { 48, 16, 16 } } do
		local x, y, lean = st[1], st[2], st[3]
		grain(x, y - 6, -90 + lean)
		for k = 0, 2 do
			local px = x - lean * 0.14 * k * 0.9 * 0.5 + 0
			local py = y + k * 8 - 2
			grain(px - 3, py, -135 + lean)
			grain(px + 3, py, -45 + lean)
		end
	end
	S.dragon_dynasty = { field = "chief", c = { 0x8A5A1F, 0x6E4414, 0xF2CF66, 0 }, main = list }
end

-- Expansion: sails and far horizons ----------------------------------------------------------------------------------

--- The Flagship: a great three-masted ship, gilded pennants flying.
S.rocket = {
	field = "rays",
	c = { 0x10324A, 0x0A2233, 0xF4F1E8, 0xFFC24A },
	main = {
		poly({ 2, 40, 62, 42, 54, 60, 11, 60 }),
		poly({ 2, 33, 15, 33, 15, 42, 2, 42 }),
		poly({ 24, 11, 40, 11, 45, 37, 19, 37 }),
		poly({ 7, 18, 18, 18, 21, 31, 17, 31, 17, 33, 5, 31 }),
		poly({ 46, 18, 57, 18, 60, 38, 47, 38 }),
		{ "line", 32, 3, 32, 11, 2.8 },
		{ "line", 12, 9, 12, 18, 2.8 },
		{ "line", 51, 9, 51, 18, 2.8 },
	},
	accent = {
		poly({ 32, 1, 46, 5, 32, 9 }),
		poly({ 12, 8, 23, 11, 12, 14 }),
		poly({ 51, 8, 62, 11, 51, 14 }),
		{ "box", 5, 46, 59, 50 },
	},
}
--- Ship's Helm: a ship's wheel, spokes and handles.
do
	local list: { any } = { { "ring", 32, 32, 21, 6 }, { "circle", 32, 32, 7 } }
	for i = 0, 7 do
		local a = (i / 8) * 2 * pi
		local ca, sa = cos(a), sin(a)
		table.insert(list, { "line", 32, 32, 32 + ca * 21, 32 + sa * 21, 3.8 })
		table.insert(list, { "line", 32 + ca * 24, 32 + sa * 24, 32 + ca * 30, 32 + sa * 30, 5.5 })
	end
	table.insert(list, { "erase", { "circle", 32, 32, 2.5 } })
	S.comet = { field = "plain", c = { 0x1F3A5F, 0x1F3A5F, 0xE8C98A, 0 }, main = list }
end
--- Caravan Camel: a camel of the long road, a red saddle cloth between its humps.
S.astronaut = {
	field = "wave",
	c = { 0xD9A85A, 0xC8964A, 0x3A2418, 0xB5332A },
	main = {
		poly({ 3, 16, 14, 11, 20, 14, 19, 22, 12, 25, 4, 23 }),
		{ "line", 17, 20, 21, 38, 8 },
		{ "circle", 32, 27, 9 },
		{ "circle", 46, 28, 8 },
		{ "box", 19, 30, 56, 46, 7 },
		{ "line", 24, 44, 22, 62, 4.5 },
		{ "line", 30, 44, 31, 62, 4.5 },
		{ "line", 47, 44, 46, 62, 4.5 },
		{ "line", 52, 44, 55, 62, 4.5 },
		{ "line", 55, 34, 60, 46, 2.8 },
		{ "erase", { "circle", 11, 16, 1.6 } },
	},
	accent = {
		poly({ 29, 33, 49, 33, 51, 45, 27, 45 }),
	},
}
--- Far Peaks: mountains on the horizon under a low sun.
S.ringed_planet = {
	field = "bend",
	c = { 0x2C6E91, 0x1F5573, 0xF4F1E8, 0 },
	main = {
		poly({ 1, 56, 21, 16, 33, 38, 43, 24, 63, 56 }),
		{ "erase", poly({ 13, 32, 19, 35, 23, 30, 28, 36, 21, 28 }) },
		{ "erase", poly({ 37, 34, 41, 37, 44, 33, 49, 38, 43, 29 }) },
		{ "box", 1, 58, 63, 63, 2 },
		{ "circle", 51, 11, 7 },
	},
}
--- Pole Star: the navigator's star over the swell.
S.jolly_roger = {
	field = "fess",
	c = { 0x101E44, 0x1C3468, 0xF2E9C4, 0 },
	main = {
		star(32, 25, 25, 5.5, 4),
		star(32, 25, 13, 5.5, 8),
		{ "arc", 13, 62, 10, 195, 345, 5 },
		{ "arc", 32, 62, 10, 195, 345, 5 },
		{ "arc", 51, 62, 10, 195, 345, 5 },
	},
}
--- Skyward: a balloon rising, its basket hung below.
S.kraken = {
	field = "bend",
	c = { 0x3A7CA5, 0x2B6185, 0xF7D35B, 0 },
	main = {
		{ "circle", 32, 23, 21 },
		poly({ 14, 33, 50, 33, 39, 48, 25, 48 }),
		{ "erase", ellipse_band(32, 23, 11, 23, 0, -90, 90, 3) },
		{ "erase", ellipse_band(32, 23, 11, 23, 0, 90, 270, 3) },
		{ "line", 27, 48, 28, 54, 2.5 },
		{ "line", 37, 48, 36, 54, 2.5 },
		{ "box", 26, 53, 38, 62, 1.5 },
	},
}
--- Explorer's Spyglass: a brass spyglass drawn out, trained on a far star.
S.lighthouse = {
	field = "lozenge",
	c = { 0x1A1A3E, 0x24244F, 0xE8C98A, 0xF4F1E8 },
	main = {
		{ "line", 9, 56, 22, 46, 7 },
		{ "line", 22, 46, 38, 34, 10 },
		{ "line", 38, 34, 53, 22, 14 },
		star(16, 15, 11, 3, 4),
	},
	accent = {
		{ "line", 18, 41, 26, 51, 4 },
		{ "line", 33, 27, 43, 40, 4 },
		{ "line", 49, 14, 60, 29, 5.5 },
	},
}
--- Breaching Whale: a great whale, spouting over the swell.
S.anchor = {
	field = "saltire",
	c = { 0x0E2F4A, 0x153E60, 0xD4E4EC, 0x6FC4E8 },
	main = {
		poly({ 9, 38, 18, 27, 36, 22, 52, 26, 61, 37, 58, 45, 44, 51, 26, 50, 14, 45 }),
		poly({ 11, 40, 3, 26, 0, 13, 8, 19, 13, 9, 15, 24, 20, 34 }),
		{ "erase", { "circle", 50, 34, 2 } },
		{ "arc", 14, 63, 9, 195, 345, 4.5 },
		{ "arc", 32, 63, 9, 195, 345, 4.5 },
		{ "arc", 50, 63, 9, 195, 345, 4.5 },
	},
	accent = {
		poly({ 27, 50, 44, 51, 58, 45, 60, 40, 44, 45, 28, 45 }),
		{ "line", 43, 22, 43, 10, 3.2 },
		{ "line", 43, 11, 36, 3, 3.2 },
		{ "line", 43, 11, 50, 3, 3.2 },
	},
}

-- Conflict: storm, fire and things that creep ------------------------------------------------------------------------

--- Burning Keep: a castle tower with fire on its battlements.
S.tornado = {
	field = "chevron",
	c = { 0x2A2438, 0x3A3250, 0xBFC4CC, 0xFF7A2B },
	main = {
		{ "box", 15, 27, 49, 63, 1 },
		{ "erase", { "circle", 32, 52, 6 } },
		{ "erase", { "box", 26, 52, 38, 63 } },
		{ "erase", { "box", 29, 34, 35, 42 } },
	},
	accent = {
		poly({ 11, 30, 13, 14, 20, 20, 24, 4, 31, 15, 37, 0, 42, 15, 49, 9, 53, 30, 46, 24, 39, 30, 32, 23, 25, 30, 18, 24 }),
	},
}
--- Coiled Adder: a snake in its coil, the head raised and the tongue out.
S.phantom = {
	field = "pale",
	c = { 0x3D5A2E, 0x2F4823, 0xE6D9A0, 0 },
	main = cat({
		{ "line", 10, 58, 54, 58, 8 },
		{ "line", 16, 48, 48, 48, 8 },
		{ "line", 22, 38, 42, 38, 7.5 },
		poly({ 30, 7, 17, 9, 12, 14, 18, 19, 30, 20 }),
		{ "line", 13, 14, 4, 10, 2.2 },
		{ "line", 13, 14, 4, 18, 2.2 },
		{ "erase", { "circle", 22, 13, 1.9 } },
	}, taper({ 42, 37, 49, 26, 42, 15, 28, 14 }, 7.5, 6)),
}
--- Black Scorpion: a scorpion from above, claws out, its sting curled.
do
	local claw = { 24, 22, 13, 18, 9, 9, 2, 8, 5, 2, 13, 2, 16, 11 }
	local list: { any } = {
		{ "box", 23, 16, 41, 44, 8 },
		poly(claw),
		mirror(claw),
		{ "line", 32, 44, 32, 52, 6 },
		{ "line", 32, 52, 39, 58, 5.5 },
		{ "line", 39, 58, 48, 55, 5 },
		{ "line", 48, 55, 50, 46, 4.5 },
		poly({ 46, 47, 54, 47, 51, 36 }),
	}
	for i, y in { 25, 32, 39 } do
		local out = 7 + i * 1
		table.insert(list, { "line", 25, y, out, y + 4, 3.2 })
		table.insert(list, { "line", 39, y, 64 - out, y + 4, 3.2 })
	end
	S.frost_crown = { field = "fess", c = { 0xE6DCC0, 0xD6CAA8, 0x17171F, 0 }, main = list }
end
--- Fire Arrows: two arrows crossed, flames at their heads.
S.thunder = {
	field = "check",
	c = { 0x2B1D1A, 0x3A2722, 0xE4E6EE, 0xFF7A2B },
	main = {
		{ "line", 10, 60, 48, 11, 4.2 },
		{ "line", 54, 60, 16, 11, 4.2 },
		poly({ 54, 1, 53, 17, 41, 8 }),
		poly({ 10, 1, 11, 17, 23, 8 }),
		poly({ 3, 55, 9, 63, 14, 59, 10, 53 }),
		poly({ 61, 55, 55, 63, 50, 59, 54, 53 }),
	},
	accent = {
		poly({ 36, 30, 34, 22, 39, 24, 40, 15, 46, 21, 50, 19, 48, 30, 42, 34 }),
		poly({ 28, 30, 30, 22, 25, 24, 24, 15, 18, 21, 14, 19, 16, 30, 22, 34 }),
	},
}
--- War Torch: a torch held up, burning.
S.volcano = {
	field = "bend",
	c = { 0x3A2222, 0x2A1818, 0xFFB43A, 0 },
	main = {
		poly({ 35, 0, 45, 12, 47, 21, 40, 26, 24, 26, 17, 19, 21, 9, 26, 14, 28, 6 }),
		{ "erase", poly({ 33, 12, 38, 19, 34, 24, 28, 24, 27, 18 }) },
		{ "box", 23, 28, 41, 36, 2 },
		poly({ 27, 37, 37, 37, 35, 63, 29, 63 }),
	},
}
--- Iron Scarab: a beetle from above, its wing cases split by a gold seam.
S.spider_web = {
	field = "lozenge",
	c = { 0x143A2E, 0x1C4C3C, 0xAEB6C0, 0xF4C95A },
	main = {
		{ "circle", 32, 13, 7 },
		{ "line", 28, 9, 23, 2, 3.5 },
		{ "line", 36, 9, 41, 2, 3.5 },
		{ "box", 15, 20, 49, 60, 13 },
		{ "line", 17, 28, 5, 20, 3.5 },
		{ "line", 47, 28, 59, 20, 3.5 },
		{ "line", 16, 40, 3, 40, 3.5 },
		{ "line", 48, 40, 61, 40, 3.5 },
		{ "line", 18, 51, 6, 60, 3.5 },
		{ "line", 46, 51, 58, 60, 3.5 },
	},
	accent = {
		{ "box", 19, 22, 45, 29, 3 },
		{ "box", 30.5, 29, 33.5, 59 },
		{ "line", 21, 38, 28, 42, 3 },
		{ "line", 43, 38, 36, 42, 3 },
		{ "line", 22, 48, 28, 52, 3 },
		{ "line", 42, 48, 36, 52, 3 },
	},
}
--- Driving Gale: wind in three long curling strokes.
S.cauldron = {
	field = "fess",
	c = { 0x4A5560, 0x39434C, 0xEEF2F4, 0 },
	main = {
		{ "line", 3, 21, 42, 21, 6 },
		{ "arc", 42, 12, 9, 180, 90, 6 },
		{ "line", 3, 34, 50, 34, 6 },
		{ "arc", 50, 43, 9, 270, 180, 6 },
		{ "line", 10, 58, 28, 58, 6 },
		{ "arc", 28, 51, 7, 180, 90, 6 },
	},
}

-- Reckoning: for a ruler with nothing left to lose ---------------------------------------------------------------------

--- Empty Throne: a high throne with no one on it, the crown left on the seat.
S.big_red_button = {
	field = "rays",
	c = { 0x2A1038, 0x431A58, 0xCFC7DB, 0xFFC24A },
	main = {
		poly({ 16, 8, 26, 8, 32, 0, 38, 8, 48, 8, 48, 40, 16, 40 }),
		{ "circle", 16, 7, 4.5 },
		{ "circle", 48, 7, 4.5 },
		{ "erase", { "box", 22, 13, 42, 40 } },
		{ "box", 9, 40, 55, 48, 2 },
		{ "box", 8, 26, 17, 41, 1.5 },
		{ "box", 47, 26, 56, 41, 1.5 },
		{ "box", 11, 48, 20, 63, 1 },
		{ "box", 44, 48, 53, 63, 1 },
		{ "box", 20, 54, 44, 58 },
	},
	accent = {
		poly({ 23, 40, 22, 25, 27, 31, 32, 21, 37, 31, 42, 25, 41, 40 }),
	},
}
--- Carrion Raven: a raven perched on a sword left standing in the field.
S.bat_moon = {
	field = "saltire",
	c = { 0x8C8FA6, 0x7B7E96, 0xE8ECF0, 0x15121F },
	main = {
		{ "box", 29, 36, 35, 55 },
		poly({ 29, 54, 35, 54, 32, 63 }),
		{ "box", 17, 33, 47, 38, 1.5 },
		{ "box", 29, 38, 35, 40 },
	},
	accent = {
		poly({ 15, 29, 22, 15, 35, 10, 44, 7, 52, 11, 62, 14, 52, 16, 47, 21, 43, 30, 30, 32, 25, 28 }),
		poly({ 22, 24, 2, 34, 6, 40, 26, 31 }),
		{ "line", 29, 30, 29, 34, 3 },
		{ "line", 38, 30, 38, 34, 3 },
		{ "erase", { "circle", 47, 11, 1.8 } },
		{ "erase", { "line", 25, 21, 40, 24, 1.8 } },
	},
}
--- Reaper's Scythe: a long blade on its snath.
S.grinning_skull = {
	field = "check",
	c = { 0x1C1C22, 0x2B2B33, 0xD8DDE4, 0xC89B5A },
	main = {
		ellipse_band(26, 30, 31, 22, -20, 196, 318, 0.1),
		poly((function()
			local out = ellipse_pts(26, 30, 33, 26, -14, 196, 322, 24)
			for _, v in ellipse_pts(30, 40, 30, 26, -14, 322, 190, 24) do
				table.insert(out, v)
			end
			return out
		end)()),
	},
	accent = {
		{ "line", 52, 8, 22, 62, 5 },
		{ "line", 30, 48, 40, 53, 4.5 },
	},
}
--- Broken Sword: a sword snapped in two, the point fallen away.
S.mirv_storm = {
	field = "plain",
	c = { 0x5A1F1F, 0x5A1F1F, 0xDDE2E8, 0 },
	main = {
		{ "circle", 28, 60, 4 },
		{ "box", 24, 48, 32, 57, 1.5 },
		{ "box", 10, 41, 46, 48, 2.5 },
		poly({ 21, 41, 35, 41, 35, 27, 31, 31, 27, 24, 21, 29 }),
		poly({ 53, 0, 57, 11, 47, 25, 43, 21, 39, 23, 37, 15 }),
	},
}
--- Tattered Banner: a torn cloth on a gilded pole, still flying.
S.warhead = {
	field = "chevron",
	c = { 0x3A1212, 0x571A1A, 0xD8C9A8, 0xF4C95A },
	main = {
		poly({ 15, 8, 60, 8, 52, 16, 60, 24, 50, 30, 56, 40, 44, 35, 40, 47, 31, 37, 25, 50, 20, 39, 15, 42 }),
	},
	accent = {
		{ "line", 12, 6, 12, 63, 5 },
		{ "circle", 12, 5, 4.5 },
	},
}
--- Sundered World: the world itself split, fire in the break.
S.radioactive = {
	field = "rays",
	c = { 0x38101C, 0x5A1626, 0x7FB8D8, 0xFFB43A },
	main = {
		{ "circle", 32, 32, 28 },
		{ "erase", ellipse_band(32, 32, 14, 28, 0, -90, 90, 2.4) },
		{ "erase", ellipse_band(32, 32, 14, 28, 0, 90, 270, 2.4) },
		{ "erase", { "line", 3, 32, 61, 32, 2.4 } },
		{ "erase", { "line", 8, 17, 56, 17, 2.4 } },
		{ "erase", { "line", 8, 47, 56, 47, 2.4 } },
	},
	accent = {
		{ "line", 37, 1, 28, 17, 6 },
		{ "line", 28, 17, 38, 32, 6 },
		{ "line", 38, 32, 26, 47, 6 },
		{ "line", 26, 47, 33, 63, 6 },
	},
}
--- The Last Hour: an hourglass with the last of its sand.
S.pumpkin_king = {
	field = "fess",
	c = { 0x6B1F1F, 0x4E1414, 0xF2E6C9, 0 },
	main = {
		{ "box", 10, 2, 54, 9, 2 },
		{ "box", 10, 55, 54, 62, 2 },
		poly({ 15, 9, 49, 9, 49, 14, 36, 30, 36, 34, 49, 50, 49, 55, 15, 55, 15, 50, 28, 34, 28, 30, 15, 14 }),
		{ "erase", poly({ 20, 12, 44, 12, 44, 13, 33, 27, 31, 27, 20, 13 }) },
		poly({ 32, 25, 37, 18, 27, 18 }),
		{ "erase", poly({ 31, 36, 33, 36, 44, 50, 44, 52, 20, 52, 20, 50 }) },
		poly({ 22, 52, 42, 52, 32, 41 }),
	},
}

return S
