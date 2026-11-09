--!strict
-- Decoder for the art the build tools pack (tools/art/pack.luau): an 8-bit coverage mask as run-length
-- pairs (value, count) in base64. Pure Luau, the same under Lune (the tests) and in the game, so the pixels a
-- player sees are the ones the contact sheets show. Nothing is rasterised on the device.
local Pack = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LOOKUP: { [number]: number } = {}
for i = 1, #B64 do
	LOOKUP[string.byte(B64, i)] = i - 1
end

--- base64 text -> bytes as a buffer.
function Pack.base64(text: string): buffer
	local n = #text
	local pad = 0
	if string.sub(text, n, n) == "=" then
		pad += 1
	end
	if string.sub(text, n - 1, n - 1) == "=" then
		pad += 1
	end
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	local len = buffer.len(out)
	for i = 1, n, 4 do
		local a = LOOKUP[string.byte(text, i)] or 0
		local b = LOOKUP[string.byte(text, i + 1)] or 0
		local c = LOOKUP[string.byte(text, i + 2)] or 0
		local d = LOOKUP[string.byte(text, i + 3)] or 0
		local v = a * 262144 + b * 4096 + c * 64 + d
		if o < len then
			buffer.writeu8(out, o, v // 65536)
		end
		if o + 1 < len then
			buffer.writeu8(out, o + 1, (v // 256) % 256)
		end
		if o + 2 < len then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

--- Run-length pairs -> a coverage mask of `count` bytes.
function Pack.unrle(data: buffer, count: number): buffer
	local out = buffer.create(count)
	local o = 0
	local n = buffer.len(data)
	local i = 0
	while i + 1 < n and o < count do
		local v, run = buffer.readu8(data, i), buffer.readu8(data, i + 1)
		if v ~= 0 then
			for k = 0, run - 1 do
				if o + k < count then
					buffer.writeu8(out, o + k, v)
				end
			end
		end
		o += run
		i += 2
	end
	return out
end

--- base64 run-length text -> mask buffer of w * h bytes.
function Pack.mask(text: string, w: number, h: number): buffer
	return Pack.unrle(Pack.base64(text), w * h)
end

--- Writes `mask` (w x h coverage) into `rgba` (a buffer of atlas_w x atlas_h x 4 bytes) at pixel (x, y) as
--- white with that coverage as alpha (the interface tints it with ImageColor3).
function Pack.blit_white(rgba: buffer, atlas_w: number, mask: buffer, w: number, h: number, x: number, y: number)
	for sy = 0, h - 1 do
		local row = ((y + sy) * atlas_w + x) * 4
		for sx = 0, w - 1 do
			local a = buffer.readu8(mask, sy * w + sx)
			local o = row + sx * 4
			buffer.writeu32(rgba, o, 0x00FFFFFF + a * 16777216)
		end
	end
end

--- As blit_white, but `mask` (w x h) shrunk by the whole factor `f` into an (w / f) x (h / f) cell: each atlas
--- pixel is the mean coverage of the f x f mask pixels under it (the glyphs ship at twice the atlas cell).
function Pack.blit_white_scaled(rgba: buffer, atlas_w: number, mask: buffer, w: number, h: number, x: number, y: number, f: number)
	local cw, ch = w // f, h // f
	local n = f * f
	for cy = 0, ch - 1 do
		local row = ((y + cy) * atlas_w + x) * 4
		for cx = 0, cw - 1 do
			local sum = 0
			for dy = 0, f - 1 do
				local base = (cy * f + dy) * w + cx * f
				for dx = 0, f - 1 do
					sum += buffer.readu8(mask, base + dx)
				end
			end
			local a = (sum + n // 2) // n
			buffer.writeu32(rgba, row + cx * 4, 0x00FFFFFF + a * 16777216)
		end
	end
end

--- Roblox's largest EditableImage side, in pixels: a strip of cells wider than this is laid out in rows (Pack.grid).
Pack.MAX_SIDE = 1024

--- `cols` square cells of `cell` px in rows no wider than MAX_SIDE: cells per row, the image's width and height.
function Pack.grid(cols: number, cell: number): (number, number, number)
	local per = math.max(1, math.min(cols, Pack.MAX_SIDE // cell))
	local rows = (cols + per - 1) // per
	return per, per * cell, rows * cell
end

--- Re-lays a one-row RGBA strip of `cols` cells (`cell` px) as Pack.grid's rows; returns the buffer, width, height.
function Pack.wrap(rgba: buffer, cols: number, cell: number): (buffer, number, number)
	local per, w, h = Pack.grid(cols, cell)
	if per >= cols then
		return rgba, cols * cell, cell
	end
	local out = buffer.create(w * h * 4)
	local sw = cols * cell
	for c = 0, cols - 1 do
		local gx, gy = (c % per) * cell, (c // per) * cell
		for y = 0, cell - 1 do
			buffer.copy(out, ((gy + y) * w + gx) * 4, rgba, (y * sw + c * cell) * 4, cell * 4)
		end
	end
	return out, w, h
end

return Pack
