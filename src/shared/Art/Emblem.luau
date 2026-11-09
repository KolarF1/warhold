--!strict
-- Our flags, drawn from a key. A country's (a Standard of the Issued rarity): a field pattern, three colours from a curated
-- palette, a charge taken from our glyph set, a darker rim, all a function of the key's hash. A Standard sold in the shop has
-- its own picture (Art/StandardData, tools/art/standards.luau) and a frame that says its rarity. Everything is a function of
-- the key, so a flag looks the same on every device and every run, and none of it is someone else's art.
-- `pixels` is pure (RGBA bytes, opaque); the client uploads it (UI/FlagArt), the tests render it.
local Pack = require("./Pack")
local IconData = require("./IconData")
local StandardData = require("./StandardData")

local Emblem = {}

Emblem.W = 57
Emblem.H = 38

local PALETTES = {
	{ 0x1F3A5F, 0xE8C547, 0xF4F1E8 },
	{ 0x7A1F2B, 0xF2E6C9, 0xD9A441 },
	{ 0x0F5C4D, 0xE9E2C8, 0xC4492F },
	{ 0x2B2F77, 0xD8DBE8, 0xF0B429 },
	{ 0x8A2D12, 0x222222, 0xF2CF66 },
	{ 0x196F6B, 0xF0E8D8, 0xDB5A42 },
	{ 0x4A2A6B, 0xE8D9A8, 0x7FD1B9 },
	{ 0x1C1C28, 0xCF3A3A, 0xE9E9E9 },
	{ 0x3D5A2E, 0xE6D9A0, 0xA8341C },
	{ 0x0B4F8A, 0xF2F2F2, 0xE04A3B },
	{ 0x6B3F1D, 0xE8C07A, 0x2B6A63 },
	{ 0xB5332A, 0x1D2A48, 0xF1E4B8 },
}

local CHARGES = { "star", "crown", "globe", "defense", "port", "city", "target", "gold", "eye", "layers", "troops", "airfield", "artillery" }

--- A well-mixed integer of a string (FNV-1a, kept in 32 bits).
function Emblem.hash(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

local _masks: { [string]: buffer } = {}
local function mask_of(name: string): buffer
	local m = _masks[name]
	if m == nil then
		m = Pack.mask(IconData.icons[name], IconData.size, IconData.size)
		_masks[name] = m
	end
	return m
end

local function rgb(c: number): (number, number, number)
	return c // 65536, (c // 256) % 256, c % 256
end

local _standard_masks: { [string]: buffer } = {}
local function standard_mask(text: string): buffer
	local m = _standard_masks[text]
	if m == nil then
		m = Pack.mask(text, StandardData.size, StandardData.size)
		_standard_masks[text] = m
	end
	return m
end

--- A Standard's field, its second colour's share at (u, v) in 0..1, `k` the flag's width over its height.
local FIELD: { [string]: (number, number, number) -> boolean } = {
	plain = function()
		return false
	end,
	pale = function(u)
		return u >= 0.5
	end,
	fess = function(_, v)
		return v >= 0.5
	end,
	bend = function(u, v, k)
		return (u - 0.5) * k + (v - 0.5) >= 0
	end,
	chief = function(_, v)
		return v < 0.3
	end,
	check = function(u, v, k)
		return (math.floor(u * k * 6) + math.floor(v * 6)) % 2 == 0
	end,
	lozenge = function(u, v, k)
		local x, y = u * k * 4, v * 4
		return (math.floor(x + y) + math.floor(x - y)) % 2 == 0
	end,
	chevron = function(u, v, k)
		return math.floor((v + math.abs(u - 0.5) * k * 0.8) * 5) % 2 == 0
	end,
	paly = function(u)
		return math.floor(u * 8) % 2 == 0
	end,
	wave = function(u, v, k)
		return math.floor((v + math.sin(u * k * 12) * 0.035) * 6) % 2 == 0
	end,
	saltire = function(u, v, k)
		return math.abs((u - 0.5) * k - (v - 0.5)) < 0.13 or math.abs((u - 0.5) * k + (v - 0.5)) < 0.13
	end,
	rays = function(u, v, k)
		return (math.atan2(v - 0.5, (u - 0.5) * k) / (2 * math.pi) * 16 + 0.25) % 1 < 0.5
	end,
}

--- What each rarity's frame is made of: the band's colour (light and dark along its width), and whether it has a second line
--- and corner studs. Honoured is a line of pewter, Storied a band and line of silver, Mythic a broad band of gold, studded.
local FRAME = {
	rare = { band = 1.2, light = 0xB9BEC6, dark = 0x70757D, line = false, studs = false, halo = false },
	epic = { band = 2.0, light = 0xEEF2F6, dark = 0x98A0AA, line = true, studs = false, halo = false },
	legendary = { band = 3.2, light = 0xFFE58A, dark = 0xB07A1E, line = true, studs = true, halo = true },
}

--- A Standard sold in the shop: its own field, charge and frame.
local function paint_standard(look: any, w: number, h: number): buffer
	local out = buffer.create(w * h * 4)
	local field = FIELD[look.field] or FIELD.plain
	local frame = FRAME[look.rarity] or FRAME.rare
	local c = look.c
	local r1, g1, b1 = rgb(c[1])
	local r2, g2, b2 = rgb(c[2])
	local rm, gm, bm = rgb(c[3])
	local ra, ga, ba = rgb(c[4])
	local main = standard_mask(look.main)
	local accent = if look.accent then standard_mask(look.accent) else nil
	local ms = StandardData.size
	local s = h / 38 -- (the frame's sizes are for the name tag's 38 px; a bigger card scales them)
	local band = frame.band * s
	local k = w / h
	local size = h - 2 * (band + 1.2 * s) -- the charge fills the height inside the frame
	local gx0, gy0 = (w - size) * 0.5, (h - size) * 0.5
	local scale = ms / size
	--- the mask's coverage at flag pixel (px, py), bilinear
	local function sample(m: buffer, px: number, py: number): number
		local sx, sy = (px - gx0) * scale - 0.5, (py - gy0) * scale - 0.5
		if sx < -1 or sy < -1 or sx >= ms or sy >= ms then
			return 0
		end
		local x0, y0 = math.floor(sx), math.floor(sy)
		local fx, fy = sx - x0, sy - y0
		local function at(x: number, y: number): number
			if x < 0 or y < 0 or x >= ms or y >= ms then
				return 0
			end
			return buffer.readu8(m, y * ms + x)
		end
		return ((at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx) * (1 - fy) + (at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx) * fy) / 255
	end
	local shadow_off = math.max(1, 1.2 * s)
	local stud = 2.3 * s
	for y = 0, h - 1 do
		local v = (y + 0.5) / h
		for x = 0, w - 1 do
			local u = (x + 0.5) / w
			-- the field, four samples to a pixel so its edges stay clean at a name tag's size
			local t = 0
			for dy = -0.25, 0.25, 0.5 do
				for dx = -0.25, 0.25, 0.5 do
					if field((x + 0.5 + dx) / w, (y + 0.5 + dy) / h, k) then
						t += 0.25
					end
				end
			end
			local r, g, b = r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t
			-- a Mythic's halo: the field lifted round the charge, falling off to the frame
			if frame.halo then
				local d = math.sqrt(((u - 0.5) * k) ^ 2 + (v - 0.5) ^ 2) / 0.62
				local g0 = math.max(0, 1 - d) * 0.55
				r, g, b = r + (255 - r) * g0 * 0.75, g + (210 - g) * g0 * 0.75, b + (120 - b) * g0 * 0.75
			end
			-- the charge: a shadow, then main, then accent
			local cm = sample(main, x + 0.5, y + 0.5)
			local ca = if accent then sample(accent, x + 0.5, y + 0.5) else 0
			local sh = math.max(sample(main, x + 0.5 - shadow_off, y + 0.5 - shadow_off), if accent then sample(accent, x + 0.5 - shadow_off, y + 0.5 - shadow_off) else 0) * 0.45
			r, g, b = r * (1 - sh), g * (1 - sh), b * (1 - sh)
			r, g, b = r + (rm - r) * cm, g + (gm - g) * cm, b + (bm - b) * cm
			r, g, b = r + (ra - r) * ca, g + (ga - g) * ca, b + (ba - b) * ca
			-- the frame
			local edge = math.min(x + 0.5, y + 0.5, w - 0.5 - x, h - 0.5 - y)
			if edge < band then
				local shine = 1 - edge / band -- light on the outside, dark within
				local rl, gl, bl = rgb(frame.light)
				local rd, gd, bd = rgb(frame.dark)
				r, g, b = rd + (rl - rd) * shine, gd + (gl - gd) * shine, bd + (bl - bd) * shine
			elseif frame.line and edge >= band + 0.8 * s and edge < band + 0.8 * s + math.max(1, 0.6 * s) then
				local rl, gl, bl = rgb(frame.light)
				r, g, b = r + (rl - r) * 0.8, g + (gl - g) * 0.8, b + (bl - b) * 0.8
			end
			if frame.studs then
				local cx = math.min(x + 0.5, w - 0.5 - x) - band * 0.5 - 0.6 * s
				local cy = math.min(y + 0.5, h - 0.5 - y) - band * 0.5 - 0.6 * s
				if cx * cx + cy * cy < stud * stud then
					r, g, b = 255, 244, 196
				end
			end
			buffer.writeu32(out, (y * w + x) * 4, math.floor(r + 0.5) + math.floor(g + 0.5) * 256 + math.floor(b + 0.5) * 65536 + 4278190080)
		end
	end
	return out
end

--- The flag of `key` at w x h px: RGBA bytes.
function Emblem.pixels(key: string, w: number, h: number): buffer
	local look = StandardData.looks[key]
	if look ~= nil then
		return paint_standard(look, w, h)
	end
	local hv = Emblem.hash(key)
	local pal = PALETTES[hv % #PALETTES + 1]
	local pattern = (hv // 16) % 8 + 1
	local charge = CHARGES[(hv // 256) % #CHARGES + 1]
	if not IconData.icons[charge] then
		charge = "star"
	end
	local flip = (hv // 4096) % 2 == 1
	local c1, c2, c3 = pal[1], pal[2], pal[3]
	if flip then
		c1, c2 = c2, c1
	end
	local out = buffer.create(w * h * 4)
	local cx = if pattern == 6 then 0.36 * w elseif pattern == 7 then 0.6 * w else 0.5 * w
	local size = 0.6 * h
	local m = mask_of(charge)
	local scale = IconData.size / size
	local gx0, gy0 = cx - size * 0.5, h * 0.5 - size * 0.5
	local aspect = w / h
	local msize = IconData.size
	local function cover(px: number, py: number): number
		local sx, sy = (px - gx0) * scale, (py - gy0) * scale
		if sx < 0 or sy < 0 or sx >= msize or sy >= msize then
			return 0
		end
		return buffer.readu8(m, math.floor(sy) * msize + math.floor(sx)) / 255
	end
	for y = 0, h - 1 do
		local v = (y + 0.5) / h
		for x = 0, w - 1 do
			local u = (x + 0.5) / w
			local use2
			if pattern == 1 then
				use2 = false
			elseif pattern == 2 then
				use2 = v >= 0.5
			elseif pattern == 3 then
				use2 = u >= 0.5
			elseif pattern == 4 then
				use2 = u + v * 0.75 >= 1.0
			elseif pattern == 5 then
				use2 = v >= 1 / 3 and v < 2 / 3
			elseif pattern == 6 then
				use2 = math.abs(u - 0.36) < 0.085 or math.abs(v - 0.5) < 0.12
			elseif pattern == 7 then
				use2 = math.abs(v - 0.5) < 0.5 * (0.62 - u) / 0.62 and u < 0.62
			else
				use2 = math.abs(u - v) * math.min(aspect, 1.6) < 0.1 or math.abs(u + v - 1) * math.min(aspect, 1.6) < 0.1
			end
			local r, g, b = rgb(if use2 then c2 else c1)
			-- the charge: a dark shadow one pixel down and right, then the glyph
			local sh = cover(x - 1 + 0.5, y - 1 + 0.5) * 0.45
			if sh > 0 then
				r, g, b = r * (1 - sh), g * (1 - sh), b * (1 - sh)
			end
			local a = cover(x + 0.5, y + 0.5)
			if a > 0 then
				local cr, cg, cb = rgb(c3)
				r, g, b = r * (1 - a) + cr * a, g * (1 - a) + cg * a, b * (1 - a) + cb * a
			end
			-- the rim: a darker frame two pixels wide
			local edge = math.min(x, y, w - 1 - x, h - 1 - y)
			if edge < 2 then
				local k = if edge == 0 then 0.55 else 0.8
				r, g, b = r * k, g * k, b * k
			end
			buffer.writeu32(out, (y * w + x) * 4, math.floor(r + 0.5) + math.floor(g + 0.5) * 256 + math.floor(b + 0.5) * 65536 + 4278190080)
		end
	end
	return out
end

return Emblem
