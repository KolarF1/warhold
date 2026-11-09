--!native
-- Landmarks (Conquer the World's own system, not part of upstream): a handful of fixed sites on
-- the map that reward whoever holds the ground under them, so a war has places worth fighting for.
--
-- They are derived from the map alone (no RNG draw, no snapshot field), so every Sim and every
-- client mirror agrees on where they are, and the upstream parity / mirror tests are untouched.
-- Off unless the match config says `landmarks = true`.
--
--   Mint      +MINT_GOLD_BONUS of the owner's passive gold income, per Mint held
--   Garrison  +GARRISON_CAP_BONUS of the owner's troop cap, per Garrison held
--   Citadel   +CITADEL_DEF_BONUS defence            Harbor   +HARBOR_TRADE_BONUS trade gold
--   Granary   +GRANARY_REGEN_BONUS troop regrowth   Foundry  +FOUNDRY_REBATE of a building's cost back
-- Held = the owner of the site's tile, never a mid-air or neutral tile (owner 0 earns nothing).

local Rules = require("./Rules")
local SimLandmarks = {}

SimLandmarks.KIND_MINT = 1
SimLandmarks.KIND_GARRISON = 2
SimLandmarks.KIND_CITADEL = 3
SimLandmarks.KIND_HARBOR = 4
SimLandmarks.KIND_GRANARY = 5
SimLandmarks.KIND_FOUNDRY = 6
SimLandmarks.KIND_NAMES = { "Gold Mine", "Garrison", "Citadel", "Lighthouse", "Granary", "Forge" }
--- The badge's mark on the map and what holding one does, per kind.
SimLandmarks.KIND_GLYPHS = { "$", "+", "#", "~", "%", "^" }
--- The icon and tile colour of each kind on the map.
SimLandmarks.KIND_ICONS = { "lm_mine", "lm_garrison", "lm_citadel", "lm_harbor", "wheat", "lm_foundry" }
SimLandmarks.KIND_LINES = { "+20% gold", "+8% troop cap", "+8% defence", "+25% trade gold", "+15% troop regrowth", "+5% building refund" }
SimLandmarks.MINT_GOLD_BONUS = 0.20
SimLandmarks.GARRISON_CAP_BONUS = 0.08
SimLandmarks.CITADEL_DEF_BONUS = 0.08
SimLandmarks.HARBOR_TRADE_BONUS = 0.25
SimLandmarks.GRANARY_REGEN_BONUS = 0.15
SimLandmarks.FOUNDRY_REBATE = 0.05
SimLandmarks.COUNT = 12

local readi32 = buffer.readi32
local readu8 = buffer.readu8

--- The sea-coast tile nearest `t` (contestable land beside the open sea, Defs.T_OCEAN = 0, not a lake) not in `taken`,
--- or -1. A Lighthouse stands there (playtest 2026-11-08: they stood in the middle of the land). Pure in the map.
function SimLandmarks.sea_coast_near(map: any, t: number, taken: { [number]: boolean }): number
	local nc = map.coast_count
	if type(nc) ~= "number" or nc <= 0 or map.terrain == nil then
		return -1
	end
	local W, H = map.W, map.H
	local tx, ty = t % W, t // W
	local terr = map.terrain
	local best, best_d = -1, math.huge
	for k = 0, nc - 1 do
		local c = map:coast_tile(k)
		if not taken[c] and map:is_contestable(c) then
			local cx, cy = c % W, c // W
			local dx, dy = cx - tx, cy - ty
			local d = dx * dx + dy * dy
			if d < best_d then
				local sea = (cx > 0 and readu8(terr, c - 1) == 0)
					or (cx < W - 1 and readu8(terr, c + 1) == 0)
					or (cy > 0 and readu8(terr, c - W) == 0)
					or (cy < H - 1 and readu8(terr, c + W) == 0)
				if sea then
					best, best_d = c, d
				end
			end
		end
	end
	return best
end

--- The sites of `map`: { { tile = i, kind = k }, … }, evenly spread through the land tiles in scan
--- order (so they spread over the rows), the kinds in turn. Pure in the map.
function SimLandmarks.sites(map: any, count: number?): { { tile: number, kind: number } }
	local n = count or SimLandmarks.COUNT
	local out = {}
	local land = map.land_count
	if land <= 0 then
		return out
	end
	-- (none in the World map's frozen waste, Rules.frozen_from; 2026-11-09, the owner: no landmarks inland in
	-- Antarctica. Land tiles run in scan order, so the land before its first frozen row is a prefix)
	local frozen = Rules.frozen_from(map)
	if frozen < map.W * map.H then
		local lo, hi = 0, land
		while lo < hi do
			local mid = (lo + hi) // 2
			if map:land_tile(mid) < frozen then
				lo = mid + 1
			else
				hi = mid
			end
		end
		land = math.max(1, lo)
	end
	local taken = {}
	for i = 1, n do
		local k = math.floor((i - 0.5) * land / n)
		-- walk to the next contestable tile that is not already a site
		local tile = map:land_tile(math.min(k, land - 1))
		local guard = 0
		while (not map:is_contestable(tile) or taken[tile]) and guard < land do
			k = (k + 1) % land
			tile = map:land_tile(k)
			guard += 1
		end
		if guard < land then
			local kind = (i - 1) % #SimLandmarks.KIND_NAMES + 1
			if kind == SimLandmarks.KIND_HARBOR then
				-- a Lighthouse: on the sea coast nearest its spot (where the map has one)
				local c = SimLandmarks.sea_coast_near(map, tile, taken)
				if c >= 0 then
					tile = c
				end
			end
			taken[tile] = true
			table.insert(out, { tile = tile, kind = kind })
		end
	end
	return out
end

--- Per owner id: the landmarks held by kind, for a list of sites and an owner buffer.
function SimLandmarks.held(sites: { { tile: number, kind: number } }, owner: buffer): { [number]: { number } }
	local held = {}
	for _, s in sites do
		local id = readi32(owner, s.tile * 4)
		if id > 0 then
			local h = held[id]
			if h == nil then
				h = { 0, 0, 0, 0, 0, 0 }
				held[id] = h
			end
			h[s.kind] += 1
		end
	end
	return held
end

function SimLandmarks.install(Sim: any)
	--- Called from Sim.new after the map is known.
	function Sim._init_landmarks(self: any, cfg: { [string]: any })
		self.landmarks_on = cfg.landmarks == true
		self.landmark_sites = if self.landmarks_on then SimLandmarks.sites(self.map) else {}
		self.landmark_held = {} :: { [number]: { number } }
	end
end

return SimLandmarks
