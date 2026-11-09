--!nonstrict
-- Depth Phase 2 (docs/DEPTH_DESIGN.md): taxes, unrest and revolts, manpower, food, the four province buildings, forts
-- and supply lines. Once a second for every realm; the regrowth draw on manpower each tick (Sim._economy_tick).
--
-- Per owner (a depth match): o_tax 1-4 (Low / Fair / High / Crushing), o_unrest 0-100, o_mp (manpower pool), o_food
-- (stockpile), o_ptax (province taxes a second), o_food_rate (net food a second), o_lost (war losses, decaying),
-- o_flow_last (the troop counters a second ago), o_unrest_add (one-off unrest still to come: no reason for war, a new
-- ruler), o_revolt_at (the tick of the next revolt check).
-- The buildings (Defs.S_FARM, S_MARKET, S_BARRACKS, S_FORT) count by their finished levels (o_alevel).
local Defs = require("./Defs")
local Depth = require("../Data/Depth")

local SimEconomy = {}

local readu16 = buffer.readu16
local TICK_RATE = Defs.TICK_RATE

SimEconomy.TAX_KEYS = { "low", "fair", "high", "crushing" }
SimEconomy.TAX_INDEX = { low = 1, fair = 2, high = 3, crushing = 4 }

function SimEconomy.install(C: any)
	function C:_init_economy()
		if self.depth == nil then
			return
		end
		local MAXO = self.MAXO
		self.o_tax = table.create(MAXO + 1, 2)
		self.o_unrest = table.create(MAXO + 1, 0.0)
		self.o_mp = table.create(MAXO + 1, 0.0)
		self.o_food = table.create(MAXO + 1, self.dp.food_start)
		self.o_ptax = table.create(MAXO + 1, 0.0)
		self.o_food_rate = table.create(MAXO + 1, 0.0)
		self.o_lost = table.create(MAXO + 1, 0.0)
		self.o_flow_last = table.create(MAXO + 1, 0.0)
		self.o_unrest_add = table.create(MAXO + 1, 0.0)
		self.o_revolt_at = table.create(MAXO + 1, 0)
		self.o_pl_lost = table.create(MAXO + 1, 0.0)
		self.o_mp_rate = table.create(MAXO + 1, self.dp.mp_rate / TICK_RATE)
		self.o_mp_top = table.create(MAXO + 1, self.dp.mp_cap)
		--- province -> the fort's level and owner there (the strongest standing), for the attack loop
		self.p_fort = {}
		self.p_fort_owner = {}
		self.d_realm = {}
		self._realm_sent = {}
		-- (the depth multipliers ride on the economy's multiplier pass: SimDoctrines._refresh_mults)
		self.mults_on = true
	end

	local function lvl(self: any, id: number, kind: number): number
		return self.o_alevel[id * 16 + kind] or 0
	end

	--- Troops `id` has lost at war so far: sent and shipped, less what came home and what still marches, plus what died
	--- at home defending and under fire (the Sim's troop counters, dbg_flow).
	local function lost_so_far(self: any, id: number, marching: number): number
		local f = self.dbg_flow
		local b = id * 5
		return f[b] + f[b + 1] - f[b + 4] - marching + f[b + 2] + f[b + 3]
	end

	--- Once a second: every realm's taxes, food, manpower ceiling, unrest and revolts.
	function C:_economy_depth_second()
		local dp = self.dp
		local P = self.P
		local tick = self.tick
		local era = math.max(self.era or 1, 1)
		-- troops marching per owner, one pass over the attacks
		local marching = {}
		for _, a in self.attacks do
			-- (claiming open land is no war: only marches on a realm eat a soldier's rations)
			if not a.dead and a.target ~= 0 then
				marching[a.attacker] = (marching[a.attacker] or 0) + math.max(a.troops, 0)
			end
		end
		-- per owner: what its provinces yield
		local tax_base = table.create(self.owner_total, 0.0)
		local food_base = table.create(self.owner_total, 0.0)
		for p = 1, P.n do
			local h = self.p_holder[p]
			if h ~= 0 then
				local v = P.size[p] * P.w[p]
				tax_base[h] += v
				local tr = P.terr[p]
				if tr == 1 then
					food_base[h] += v * dp.food_plains
				elseif tr == 2 then
					food_base[h] += v * dp.food_hills
				end
			end
		end
		local o_alive, o_spawned, o_kind = self.o_alive, self.o_spawned, self.o_kind
		for id = 1, self.owner_total do
			if o_alive[id] == 0 or o_spawned[id] == 0 or o_kind[id] == Defs.KIND_TRIBE then
				continue
			end
			local tax = self.o_tax[id]
			-- manpower's refill a tick and ceiling, as shares of the cap (read every tick by _draw_manpower)
			local bk = lvl(self, id, Defs.S_BARRACKS)
			self.o_mp_rate[id] = dp.mp_rate * (1 + dp.barracks_mp * bk + self:lev(id, "mp")) / TICK_RATE
			self.o_mp_top[id] = dp.mp_cap + dp.barracks_mp_cap * bk
			-- gold: the provinces' taxes and the markets, at the tax rate
			self.o_ptax[id] = (tax_base[id] * dp.tax_per_tile + lvl(self, id, Defs.S_MARKET) * dp.market_gold) * dp.tax_gold[tax]
			-- food: plains and hills and the farms make it; troops eat it, more of them at war
			local march = marching[id] or 0
			local made = (food_base[id] + dp.food_capital + lvl(self, id, Defs.S_FARM) * dp.farm_food) * math.max(1 + self:lev(id, "food"), 0.2)
			local eaten = self.o_troops[id] * dp.food_home + march * dp.food_war + self:_army_food(id)
			local rate = made - eaten
			self.o_food_rate[id] = rate
			local cap_food = math.max(made, 1) * dp.food_store_s + dp.food_start
			self.o_food[id] = math.clamp(self.o_food[id] + rate, 0, cap_food)
			-- war losses this second, decaying
			local lost = lost_so_far(self, id, march)
			local fresh = math.max(lost - self.o_flow_last[id], 0)
			self.o_flow_last[id] = lost
			self.o_lost[id] = self.o_lost[id] * dp.exhaust_decay + fresh
			self.o_pl_lost[id] *= dp.exhaust_decay
			-- unrest: drifts toward its target
			local cap = math.max(self.o_cap[id], 1)
			local exhaust = math.min(dp.exhaust_max, dp.exhaust_k * self.o_lost[id] / cap + self.o_pl_lost[id])
			local allowed = dp.provinces_base + dp.provinces_per_age * era + self:lev(id, "prov")
			local over = math.max(self.o_pheld[id] - allowed, 0) * dp.overextend_k
			local target = dp.tax_unrest[tax] + exhaust + math.min(over, dp.overextend_max) + self:_unrest_extra(id)
			if self.o_food[id] <= 0 then
				target += dp.starving_unrest
			end
			target = math.clamp(target, 0, 100)
			local u = self.o_unrest[id]
			local step = dp.unrest_rate * (if target > u then 1 else 2)
			if math.abs(target - u) <= step then
				u = target
			else
				u += if target > u then step else -step
			end
			-- one-off shocks land at once
			local add = self.o_unrest_add[id]
			if add ~= 0 then
				u += add
				self.o_unrest_add[id] = 0
			end
			u = math.clamp(u, 0, 100)
			self.o_unrest[id] = u
			-- a revolt now and then while it runs high
			if u >= dp.revolt_at and tick >= self.o_revolt_at[id] then
				self.o_revolt_at[id] = tick + dp.revolt_s * TICK_RATE
				if self.o_revolt_at[id] > 0 and self:_revolt(id) then
					self.o_unrest[id] = math.max(u - dp.revolt_relief, 0)
				end
			elseif u < dp.revolt_at and self.o_revolt_at[id] < tick then
				-- (the first revolt comes revolt_s after unrest climbs that high)
				self.o_revolt_at[id] = tick + dp.revolt_s * TICK_RATE
			end
			-- the AI sets its taxes now and then by its unrest and its purse
			if self.o_ai[id] == 1 and (tick // TICK_RATE + id) % 30 == 0 then
				self:_ai_tax(id)
			end
		end
	end

	--- An AI realm's taxes: low when restless, high when calm (and poor), fair between.
	function C:_ai_tax(id: number)
		local u = self.o_unrest[id]
		local want = 2
		if u >= 60 then
			want = 1
		elseif u < 20 and self.o_gold[id] < 150000 then
			want = 3
		elseif u < 12 then
			want = 3
		end
		self.o_tax[id] = want
	end

	--- Extra unrest from later systems (wars without a reason, a new ruler, traits): 0 here.
	function C:_unrest_extra(_id: number): number
		return 0
	end

	--- Depth levers (SimRulers overrides it once installed): 0 here.
	function C:lev(_id: number, _lever: string): number
		return 0
	end

	--- Food the armies of `id` eat a second (Phase 5): 0 here.
	function C:_army_food(_id: number): number
		return 0
	end

	--- Unrest's toll: gold and regrowth fall from revolt_at's half up (x unrest_floor at 100).
	function C:unrest_mult(id: number): number
		local u = self.o_unrest[id]
		local from = self.dp.unrest_hurts
		if u <= from then
			return 1.0
		end
		return 1.0 - (1.0 - self.dp.unrest_floor) * (u - from) / (100 - from)
	end

	--- The depth multipliers of `id` on top of the rest (SimDoctrines._refresh_mults): taxes, unrest, food, barracks.
	function C:_depth_mults(id: number, gold: number, cap: number, atk: number, def: number, regen: number)
		if self.o_tax == nil or self.o_kind[id] == Defs.KIND_TRIBE then
			return gold, cap, atk, def, regen
		end
		local dp = self.dp
		local um = self:unrest_mult(id)
		gold *= dp.tax_gold[self.o_tax[id]] * um
		regen *= um
		cap *= 1.0 + dp.barracks_cap * math.min(lvl(self, id, Defs.S_BARRACKS), dp.barracks_cap_levels)
		if self.o_food[id] <= 0 then
			regen *= dp.starving_regen
			atk *= dp.starving_atk
		end
		return gold, cap, atk, def, regen
	end

	--- Regrowth draws on manpower: no more troops grow than the pool holds. The pool refills each tick from the
	--- troop cap, faster with barracks, up to mp_cap of the cap.
	function C:_draw_manpower(id: number, grown: number): number
		local mp = self.o_mp
		if mp == nil or self.o_kind[id] == Defs.KIND_TRIBE then
			return grown
		end
		-- (the refill and ceiling shares, set once a second by _economy_depth_second)
		local cap = self.o_cap[id]
		local top = cap * self.o_mp_top[id]
		local m = math.min(mp[id] + cap * self.o_mp_rate[id], top)
		local take = math.min(grown, math.floor(m))
		mp[id] = m - math.max(take, 0)
		return take
	end

	--- The tax intent: "low" | "fair" | "high" | "crushing".
	function C:set_tax(id: number, key: string): boolean
		local i = SimEconomy.TAX_INDEX[key]
		if self.o_tax == nil or i == nil or self.o_tax[id] == i then
			return false
		end
		self.o_tax[id] = i
		self:_refresh_mults()
		self:_realm_row(id, true)
		return true
	end

	--- A revolt in `id`'s realm: a held province away from its capital breaks free (its land goes open, a few ticks at
	--- a time). True when one did.
	function C:_revolt(id: number): boolean
		local P = self.P
		local home = self:province_at(self.o_spawn_tile[id])
		local best, bs = 0, -1
		for p = 1, P.n do
			if self.p_holder[p] == id and p ~= home then
				-- (the least loyal: far from the capital, low development; a seeded draw breaks ties)
				local s = self.rng:randf() * 0.5 + (10 - P.dev[p]) * 0.1
				if s > bs then
					best, bs = p, s
				end
			end
		end
		if best == 0 then
			return false
		end
		self:handover(best, id, 0)
		self:msg(id, Defs.MSG_BAD, string.format("%s rises in revolt and breaks away", P.name[best]))
		self:msg(-1, Defs.MSG_INFO, string.format("%s revolts against %s", P.name[best], self.o_name[id]))
		self:_on_revolt(id, best)
		return true
	end

	--- Hook: `p` revolted against `id` (later phases: prestige).
	function C:_on_revolt(_id: number, _p: number) end

	--- A province lost costs unrest for a while (exhaustion).
	local prev_changed = C._on_province_changed
	function C:_on_province_changed(p: number, old: number, holder: number)
		prev_changed(self, p, old, holder)
		if self.o_pl_lost ~= nil and old ~= 0 and old ~= holder then
			self.o_pl_lost[old] += self.dp.province_lost_unrest
		end
	end

	--- At the end of each second, after every system has moved them: the realm rows that changed.
	function C:_realm_rows_second()
		if self.o_tax == nil then
			return
		end
		for id = 1, self.owner_total do
			if self.o_alive[id] == 1 and self.o_spawned[id] == 1 and self.o_kind[id] ~= Defs.KIND_TRIBE then
				self:_realm_row(id)
			end
		end
	end

	--- The realm row of `id` for the clients (only what moved: unrest by a point, the pools by 2 %), unless `force`.
	function C:_realm_build(id: number): { number }
		return {
			id,
			self.o_tax[id],
			math.floor(self.o_unrest[id] + 0.5),
			math.floor(self.o_mp[id]),
			math.floor(self.o_food[id]),
			math.floor(self.o_food_rate[id] * 10 + 0.5),
			math.floor(self.o_ptax[id]),
			math.floor(if self.o_prestige ~= nil then self.o_prestige[id] else 0),
		}
	end

	function C:_realm_row(id: number, force: boolean?)
		local row = self:_realm_build(id)
		local last = self._realm_sent[id]
		if not force and last ~= nil then
			local same = last[2] == row[2] and last[3] == row[3]
				and math.abs(last[4] - row[4]) <= math.max(50, 0.02 * math.abs(row[4]))
				and math.abs(last[5] - row[5]) <= math.max(20, 0.02 * math.abs(row[5]))
				and math.abs(last[6] - row[6]) <= math.max(10, 0.05 * math.abs(row[6]))
				and math.abs(last[7] - row[7]) <= math.max(10, 0.02 * math.abs(row[7]))
				and last[8] == row[8]
			if same then
				return
			end
		end
		self._realm_sent[id] = row
		local d = self.d_realm
		d[#d + 1] = row
	end

	--- Every realm row (a snapshot): as they stand now.
	function C:_realm_rows(): { { number } }
		local out = {}
		if self.o_tax == nil then
			return out
		end
		-- (built fresh, never marked sent: the players already in hear changes as ever)
		for id = 1, self.owner_total do
			if self.o_alive[id] == 1 and self.o_spawned[id] == 1 and self.o_kind[id] ~= Defs.KIND_TRIBE then
				table.insert(out, self:_realm_build(id))
			end
		end
		return out
	end

	--- A fort's level in province `p` that guards `defender`'s land there (0: none).
	function C:fort_level(p: number, defender: number): number
		if self.p_fort_owner[p] == defender then
			return self.p_fort[p] or 0
		end
		return 0
	end

	--- The forts by province, recomputed for province `p` from the buildings standing there.
	function C:_refresh_fort(p: number)
		if p == 0 or self.p_fort == nil then
			return
		end
		local best, owner = 0, 0
		for _, s in self.structs do
			if s.kind == Defs.S_FORT and not s.dead and readu16(self.prov, s.tile * 2) == p then
				local l = if s.active then s.level else 0
				if l > best then
					best, owner = l, s.owner
				end
			end
		end
		self.p_fort[p] = if best > 0 then best else nil
		self.p_fort_owner[p] = if best > 0 then owner else nil
	end

	--- Supply lines: an attack's losses grow with its distance from the attacker's nearest held province capital.
	function C:supply_mult(id: number, t: number): number
		local P = self.P
		if P == nil or t < 0 then
			return 1.0
		end
		local W = self.W
		local x, y = t % W, t // W
		local best = math.huge
		for p = 1, P.n do
			if self.p_holder[p] == id then
				local c = P.cap[p]
				local dx, dy = math.abs(c % W - x), math.abs(c // W - y)
				local d = math.max(dx, dy)
				if d < best then
					best = d
				end
			end
		end
		if best == math.huge then
			return 1.0 + self.dp.supply_max
		end
		local dp = self.dp
		local toll = dp.supply_max * math.max(1 + self:lev(id, "supply"), 0)
		return 1.0 + math.clamp((best - dp.supply_free) / dp.supply_span, 0, 1) * toll
	end
end

return SimEconomy
