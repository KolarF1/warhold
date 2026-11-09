--!nonstrict
-- Depth Phase 1 (docs/DEPTH_DESIGN.md): provinces in the Sim. Land is still taken tile by tile; a province is held by
-- the owner of more than Depth hold_share of its land. Income and the troop cap count an owner's land by its provinces
-- (`eff_tiles`): every held province by its weight (development, terrain), the land in provinces it doesn't hold at
-- loose_land. Buildings need a free slot in their province.
--
-- State (a depth match only): prov (the grid), P (Core/Provinces), p_holder[p], p_hcount[p] (the holder's tiles
-- there at the last count), p_struct[p] (buildings standing in it), o_heldw[id] (sum of size x weight of the provinces
-- it holds), o_heldt[id] (its own tiles in them), o_pheld[id] (how many), p_cnt[p] (owner -> its tiles there, kept by
-- set_owner as tiles change hands, SimState) and the provinces that changed (dirty), whose holders _provinces_tick
-- settles each tick from those counts (no tile is read again: a recount of the tiles cost 40% of a tick). Clients hear
-- holders change in the delta's `dp.h`.
local Defs = require("./Defs")
local Provinces = require("./Provinces")
local Depth = require("../Data/Depth")

local SimProvinces = {}

local readu16 = buffer.readu16
local readu8, writeu8 = buffer.readu8, buffer.writeu8

function SimProvinces.install(C: any)
	--- Sets up the provinces of a depth match (cfg.depth "long" / "quick" and a map that has them).
	function C:_init_provinces(cfg: any)
		self.depth = nil
		self.dp = nil
		local key = if type(cfg.depth) == "string" then cfg.depth else nil
		local pace = Depth.pace(key)
		if pace == nil then
			return
		end
		local P = Provinces.for_map(self.map)
		if P == nil then
			return
		end
		self.depth = key
		self.dp = pace
		self.P = P
		self.prov = P.grid
		local n = P.n
		self.p_holder = table.create(n, 0)
		self.p_hcount = table.create(n, 0)
		self.p_struct = table.create(n, 0)
		self.p_cnt = table.create(n, false)
		for p = 1, n do
			self.p_cnt[p] = {}
		end
		self.p_dirty = buffer.create(n + 1)
		self.p_dirty_list = {}
		self.p_dirty_at = 1
		local MAXO = self.MAXO
		self.o_heldw = table.create(MAXO + 1, 0.0)
		self.o_heldt = table.create(MAXO + 1, 0)
		self.o_pheld = table.create(MAXO + 1, 0)
		self.d_prov = {}
		--- whole provinces passing to a new owner a few ticks at a time: { p, from, to, next index }
		self.p_handover = {}
	end

	--- Province `p`'s land of `from` passes to `to` (0: open land), handover_per_tick tiles a tick. Revolts, peace
	--- deals, sieges.
	function C:handover(p: number, from: number, to: number)
		if self.prov == nil or p <= 0 then
			return
		end
		table.insert(self.p_handover, { p, from, to, 0 })
	end

	--- Each tick: the handovers under way.
	function C:_handover_tick()
		local q = self.p_handover
		if q == nil or #q == 0 then
			return
		end
		local P = self.P
		local budget = self.dp.handover_per_tick
		local owner = self.owner
		while budget > 0 and #q > 0 do
			local h = q[1]
			local p, from, to = h[1], h[2], h[3]
			local off, size = P.off[p], P.size[p]
			local i = h[4]
			while i < size and budget > 0 do
				local t = buffer.readi32(P.tiles, (off + i) * 4)
				if buffer.readi32(owner, t * 4) == from and (to == 0 or self.o_alive[to] == 1) then
					self:set_owner(t, to)
					budget -= 1
				end
				i += 1
			end
			h[4] = i
			if i >= size then
				table.remove(q, 1)
			end
		end
	end

	--- Tile `t` passed from `old` to `nw` (set_owner, SimState): its province's counts, and the province to settle.
	function C:_prov_moved(t: number, old: number, nw: number)
		local p = readu16(self.prov, t * 2)
		if p == 0 then
			return
		end
		local c = self.p_cnt[p]
		if old ~= 0 then
			local v = c[old]
			c[old] = if v == nil or v <= 1 then nil else v - 1
		end
		if nw ~= 0 then
			c[nw] = (c[nw] or 0) + 1
		end
		if readu8(self.p_dirty, p) == 0 then
			writeu8(self.p_dirty, p, 1)
			local l = self.p_dirty_list
			l[#l + 1] = p
		end
	end

	--- The province of tile `t` (0: none, or no provinces in this match).
	function C:province_at(t: number): number
		local g = self.prov
		if g == nil or t < 0 or t >= self.N then
			return 0
		end
		return readu16(g, t * 2)
	end

	--- Settles province `p`: its holder from its counts, and the sums of the holders before and after.
	function C:_recount_province(p: number)
		local P = self.P
		local size = P.size[p]
		local best, bc = 0, 0
		for o, c in self.p_cnt[p] do
			if c > bc or (c == bc and o < best) then
				best, bc = o, c
			end
		end
		local holder = if bc > size * self.dp.hold_share then best else 0
		local old = self.p_holder[p]
		local wt = size * P.w[p]
		if old ~= 0 then
			self.o_heldw[old] -= wt
			self.o_heldt[old] -= self.p_hcount[p]
			self.o_pheld[old] -= 1
		end
		if holder ~= 0 then
			self.o_heldw[holder] += wt
			self.o_heldt[holder] += bc
			self.o_pheld[holder] += 1
		end
		self.p_holder[p] = holder
		self.p_hcount[p] = if holder ~= 0 then bc else 0
		if holder ~= old then
			local d = self.d_prov
			d[#d + 1] = p
			d[#d + 1] = holder
			self:_on_province_changed(p, old, holder)
		end
	end

	--- Hook: province `p` passed from `old` to `holder` (0: nobody). Later phases listen here.
	function C:_on_province_changed(_p: number, _old: number, _holder: number) end

	--- Each tick: a few of the dirty provinces recounted, oldest first.
	function C:_provinces_tick()
		if self.prov == nil then
			return
		end
		self:_handover_tick()
		local l = self.p_dirty_list
		local at = self.p_dirty_at
		local stop = math.min(#l, at + self.dp.recount_per_tick - 1)
		for i = at, stop do
			local p = l[i]
			writeu8(self.p_dirty, p, 0)
			self:_recount_province(p)
		end
		at = stop + 1
		if at > #l then
			table.clear(l)
			at = 1
		elseif at > 512 then
			-- (the list is consumed from the front: compact it now and then)
			table.move(l, at, #l, 1)
			for i = #l - at + 2, #l do
				l[i] = nil
			end
			at = 1
		end
		self.p_dirty_at = at
	end

	--- Recounts every province at once (the start of play, and tests).
	function C:recount_provinces()
		if self.prov == nil then
			return
		end
		for p = 1, self.P.n do
			writeu8(self.p_dirty, p, 0)
			self:_recount_province(p)
		end
		table.clear(self.p_dirty_list)
		self.p_dirty_at = 1
	end

	--- The land of `id` as the economy counts it: its provinces by weight, the rest at loose_land. Raw tiles without
	--- provinces (frozen waste half: the old rule).
	function C:eff_tiles(id: number): number
		if self.prov == nil then
			return self.o_tiles[id] - 0.5 * self.o_frozen[id]
		end
		local loose = self.o_tiles[id] - self.o_heldt[id]
		return self.o_heldw[id] + self.dp.loose_land * math.max(loose, 0)
	end

	--- How many buildings province `p` has room for, and how many stand there.
	function C:province_slots(p: number): (number, number)
		if self.prov == nil or p <= 0 then
			return math.huge, 0
		end
		return self.P.slots[p], self.p_struct[p]
	end

	--- Buildings take a slot of their province (any owner's count).
	local prev_add = C.add_struct
	function C:add_struct(kind: number, id: number, t: number)
		local s = prev_add(self, kind, id, t)
		if self.prov ~= nil then
			local p = readu16(self.prov, t * 2)
			if p ~= 0 then
				self.p_struct[p] += 1
				if kind == Defs.S_FORT then
					self:_refresh_fort(p)
				end
			end
		end
		return s
	end
	local prev_destroy = C.destroy_struct
	function C:destroy_struct(s: any)
		local was_dead = s.dead
		prev_destroy(self, s)
		if not was_dead and self.prov ~= nil then
			local p = readu16(self.prov, s.tile * 2)
			if p ~= 0 then
				self.p_struct[p] -= 1
				if s.kind == Defs.S_FORT then
					self:_refresh_fort(p)
				end
			end
		end
	end
	--- A fort that changes hands or finishes guards its new owner (the attack loop reads p_fort).
	local prev_tile_changed = C._struct_tile_changed
	function C:_struct_tile_changed(t: number, old: number, nw: number)
		prev_tile_changed(self, t, old, nw)
		if self.prov ~= nil then
			local s = self.structs[buffer.readi32(self.struct_at, t * 4)]
			if s ~= nil and s.kind == Defs.S_FORT then
				self:_refresh_fort(readu16(self.prov, t * 2))
			end
		end
	end
	local prev_activate = C._activate
	function C:_activate(s: any)
		prev_activate(self, s)
		if self.prov ~= nil and s.kind == Defs.S_FORT then
			self:_refresh_fort(readu16(self.prov, s.tile * 2))
		end
	end
	local prev_upgrade = C.upgrade_struct
	function C:upgrade_struct(s: any)
		prev_upgrade(self, s)
		if self.prov ~= nil and s.kind == Defs.S_FORT then
			self:_refresh_fort(readu16(self.prov, s.tile * 2))
		end
	end
	--- A new building needs a free slot in its province (an upgrade does not).
	local prev_place = C.place
	function C:place(id: number, kind: number, t: number)
		local r = prev_place(self, id, kind, t)
		if self.prov ~= nil and r.tile >= 0 and r.upgrade_sid == 0 then
			local p = readu16(self.prov, r.tile * 2)
			if p ~= 0 and self.p_struct[p] >= self.P.slots[p] then
				return { tile = -1, upgrade_sid = 0, reason = "no_slot", province = p }
			end
		end
		return r
	end
	local prev_valid = C.valid_site
	function C:valid_site(id: number, kind: number, t: number): boolean
		if not prev_valid(self, id, kind, t) then
			return false
		end
		if self.prov ~= nil then
			local p = readu16(self.prov, t * 2)
			if p ~= 0 and self.p_struct[p] >= self.P.slots[p] then
				return false
			end
		end
		return true
	end

	--- The holders for a snapshot: { p, holder, ... } for every held province.
	function C:_province_rows(): { number }
		local out = {}
		if self.prov == nil then
			return out
		end
		for p = 1, self.P.n do
			local h = self.p_holder[p]
			if h ~= 0 then
				out[#out + 1] = p
				out[#out + 1] = h
			end
		end
		return out
	end
end

return SimProvinces
