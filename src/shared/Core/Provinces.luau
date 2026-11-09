--!strict
-- A map's provinces (docs/DEPTH_DESIGN.md, Phase 1), shared by the Sim and the clients: Data/Provinces/<Module>
-- (tools/maps/make_provinces.py) decoded onto the map as built, a scaled map (`world@80`) sampling the grid. Static, so
-- cached per map id:
--   P.n                       provinces (ids 1..n)
--   P.grid                    buffer, u16 per tile: the tile's province (0: sea, impassable, none)
--   P.name, P.country         strings; P.cap capital tile; P.terr 1 plains / 2 hills / 3 mountains / 4 frozen;
--   P.dev 1-10; P.slots       building slots
--   P.size                    the province's contestable tiles on this map
--   P.w                       its weight for income and the troop cap per tile (Data/Depth.raw_weight, normalised so
--                             the map's average tile weighs 1)
--   P.tiles, P.off            its tiles: P.tiles (buffer i32) from P.off[p] (0-based index) for P.size[p]
local MapCodec = require("./MapCodec")
local MapList = require("../Data/MapList")
local Depth = require("../Data/Depth")
local Coop = require("../Net/Coop")

local Provinces = {}

Provinces.TERRAIN_NAMES = { "Plains", "Hills", "Mountains", "Frozen" }

local RBX_SCRIPT: any = if typeof(script) == "Instance" then script else nil
local cache: { [string]: any } = {}
local data_cache: { [string]: any } = {}

--- The raw module of map `id` (nil when it has none).
function Provinces.data(id: string): any
	local base = string.match(id, "^([^@]*)") or id
	local d = data_cache[base]
	if d ~= nil then
		return if d == false then nil else d
	end
	local row = MapList.get(base)
	local module = if row ~= nil then row.module else nil
	local res: any = nil
	if module ~= nil then
		local ok, r = pcall(function(): any
			if RBX_SCRIPT ~= nil then
				local data = RBX_SCRIPT.Parent.Parent:FindFirstChild("Data")
				local folder = if data ~= nil then data:FindFirstChild("Provinces") else nil
				local mod = if folder ~= nil then folder:FindFirstChild(module) else nil
				return if mod ~= nil then (require :: any)(mod) else nil
			end
			return (require :: any)("../Data/Provinces/" .. module)
		end)
		if ok and type(r) == "table" then
			res = r
		end
	end
	data_cache[base] = if res ~= nil then res else false
	return res
end

--- The provinces of `map` (a WorldMap), or nil when its map has none.
function Provinces.for_map(map: any): any
	local key = tostring(map.id)
	local c = cache[key]
	if c ~= nil then
		return if c == false then nil else c
	end
	local d = Provinces.data(key)
	if d == nil then
		cache[key] = false
		return nil
	end
	local W, H, N = map.W, map.H, map.W * map.H
	local raw = MapCodec.zstd_decompress(MapCodec.b64decode(d.grid))
	local dw, dh = d.w, d.h
	local grid = buffer.create(N * 2)
	local readu16, writeu16 = buffer.readu16, buffer.writeu16
	local same = dw == W and dh == H
	for y = 0, H - 1 do
		-- (a solo match is built in a Coop job, sliced over frames: a row at a time)
		Coop.check()
		local sy = if same then y else math.min(math.floor((y + 0.5) * dh / H), dh - 1)
		for x = 0, W - 1 do
			local sx = if same then x else math.min(math.floor((x + 0.5) * dw / W), dw - 1)
			local t = y * W + x
			if map:is_contestable(t) then
				writeu16(grid, t * 2, readu16(raw, (sy * dw + sx) * 2))
			end
		end
	end
	-- (a scaled map's land the sample missed: its neighbour's province, a few passes)
	if not same then
		for _ = 1, 4 do
			local left = 0
			for t = 0, N - 1 do
				if t % W == 0 then
					Coop.check()
				end
				if readu16(grid, t * 2) == 0 and map:is_contestable(t) then
					local x = t % W
					local p = 0
					if x > 0 then
						p = readu16(grid, (t - 1) * 2)
					end
					if p == 0 and x < W - 1 then
						p = readu16(grid, (t + 1) * 2)
					end
					if p == 0 and t >= W then
						p = readu16(grid, (t - W) * 2)
					end
					if p == 0 and t < N - W then
						p = readu16(grid, (t + W) * 2)
					end
					if p ~= 0 then
						writeu16(grid, t * 2, p)
					else
						left += 1
					end
				end
			end
			if left == 0 then
				break
			end
		end
	end
	local list = d.list
	local n = #list
	local P: any = { n = n, grid = grid, name = {}, country = {}, cap = {}, terr = {}, dev = {}, slots = {}, size = table.create(n, 0), w = {} }
	for p = 1, n do
		local row = list[p]
		P.name[p] = row[1]
		P.country[p] = row[2]
		P.terr[p] = row[4]
		P.dev[p] = row[5]
		P.slots[p] = row[6]
		local c = row[3]
		if not same then
			local cx, cy = c % dw, c // dw
			c = math.min(math.floor(cy * H / dh), H - 1) * W + math.min(math.floor(cx * W / dw), W - 1)
		end
		P.cap[p] = c
	end
	for t = 0, N - 1 do
		if t % W == 0 then
			Coop.check()
		end
		local p = readu16(grid, t * 2)
		if p ~= 0 then
			P.size[p] += 1
		end
	end
	-- tiles by province, and each capital on its own land
	local off = table.create(n + 1, 0)
	local acc = 0
	for p = 1, n do
		off[p] = acc
		acc += P.size[p]
	end
	local tiles = buffer.create(math.max(acc, 1) * 4)
	local fill = table.clone(off)
	for t = 0, N - 1 do
		if t % W == 0 then
			Coop.check()
		end
		local p = readu16(grid, t * 2)
		if p ~= 0 then
			buffer.writei32(tiles, fill[p] * 4, t)
			fill[p] += 1
		end
	end
	P.tiles, P.off = tiles, off
	for p = 1, n do
		if P.size[p] > 0 and readu16(grid, P.cap[p] * 2) ~= p then
			P.cap[p] = buffer.readi32(tiles, off[p] * 4)
		end
	end
	-- weights, normalised so the map's land weighs as many tiles as it has
	local sum_raw, sum_n = 0.0, 0
	for p = 1, n do
		local r = Depth.raw_weight(P.dev[p], P.terr[p])
		P.w[p] = r
		sum_raw += r * P.size[p]
		sum_n += P.size[p]
	end
	local norm = if sum_n > 0 then sum_raw / sum_n else 1.0
	for p = 1, n do
		P.w[p] = P.w[p] / norm
	end
	cache[key] = P
	return P
end

--- The province of tile `t` (0: none).
function Provinces.at(P: any, t: number): number
	return buffer.readu16(P.grid, t * 2)
end

return Provinces
