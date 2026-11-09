--!nonstrict
-- Depth Phase 4 (docs/DEPTH_DESIGN.md): wars with reasons, truces, peace deals and vassals.
--
-- A war is a pair (key min * 1024 + max): `wars[key] = { a, b, since, took_a, took_b, cb_a, cb_b, prov_a, prov_b }` where
-- took_x is land x has taken from the other in it, prov_x the provinces x held when it began. Attacking a realm (a
-- player, a nation, a bot player; never a tribe or open land) you are not at war with declares war: with a reason
-- (a claim, an attack on you, your nemesis) it is just war; without one it costs unrest and standing (aggression,
-- `o_ae`, which the AI weighs). The other's pact partners, its overlord and its vassals join it. Peace ends the war: a
-- truce follows (`truces[key]` until a tick; no attack either way), and its terms: white, provinces (every province
-- the loser held at the war's start that the winner now holds more than half of passes whole), tribute (a share of the
-- loser's gold), vassal (the loser pays a share of its income to the overlord, never attacks it, joins its wars). The
-- AI answers a peace offer from the war score; a person answers a request (`peace_req`). The AI sues for peace when
-- losing.
local Defs = require("./Defs")
local Ev = require("./Ev")

local SimDiplomacy = {}

local TICK_RATE = Defs.TICK_RATE
local readi32 = buffer.readi32
local readu16 = buffer.readu16

SimDiplomacy.TERMS = { "white", "provinces", "tribute", "vassal" }
SimDiplomacy.TERM_INDEX = { white = 1, provinces = 2, tribute = 3, vassal = 4 }
SimDiplomacy.TERM_NAMES = { "White peace", "Cede provinces", "Tribute", "Vassalage" }
--- Surrender: the sender yields the terms to the other (2026-11-09: a losing player had no way to end a war the AI was
--- winning). On the wire a request's terms are 11-14 when its sender yields them.
SimDiplomacy.YIELD_INDEX = { concede = 2, pay = 3, submit = 4 }
SimDiplomacy.YIELD = 10

--- Land `taker` has taken from `victim` this match (SimState._took).
local function took_by(self: any, taker: number, victim: number): number
	local t = self._took[victim]
	return if t ~= nil then t[taker] or 0 else 0
end

local function key(a: number, b: number): number
	return if a < b then a * 1024 + b else b * 1024 + a
end
SimDiplomacy.key = key

function SimDiplomacy.install(C: any)
	function C:_init_diplomacy()
		if self.depth == nil then
			return
		end
		self.wars = {}
		self.truces = {}
		--- vassal id -> overlord id
		self.vassal_of = {}
		--- key (from * 1024 + to) -> { from, to, terms, tick }: a peace offer a person has to answer
		self.peace_req = {}
		--- aggression: what wars without a reason have cost a realm's standing (decays)
		self.o_ae = table.create(self.MAXO + 1, 0.0)
		--- province -> { holder, tick } it had before the last change (claims)
		self.p_prev = {}
		--- prestige (Phase 6) starts here so peace and wars can pay it
		self.o_prestige = table.create(self.MAXO + 1, 0.0)
		self._dip_dirty = false
	end

	local function realm(self: any, id: number): boolean
		return id > 0 and self.o_kind[id] ~= Defs.KIND_TRIBE and self.o_alive[id] == 1
	end

	--- True when `a` and `b` are at war.
	function C:at_war(a: number, b: number): boolean
		return self.wars ~= nil and self.wars[key(a, b)] ~= nil
	end

	--- The tick the truce between `a` and `b` ends (0: none).
	function C:truce_until(a: number, b: number): number
		local t = if self.truces ~= nil then self.truces[key(a, b)] else nil
		if t ~= nil and t > self.tick then
			return t
		end
		return 0
	end

	--- `id`'s overlord (0: none).
	function C:overlord(id: number): number
		return if self.vassal_of ~= nil then self.vassal_of[id] or 0 else 0
	end

	--- Why `a` may go to war with `b`: "claim", "attacked", "nemesis", "war" (already), or nil (no reason).
	function C:casus_belli(a: number, b: number): string?
		if self:at_war(a, b) then
			return "war"
		end
		-- they attacked us lately
		if self:grudge_of(a, b) then
			return "attacked"
		end
		if self.o_nemesis ~= nil and (self.o_nemesis[a] == b or self.o_nemesis[b] == a) then
			return "nemesis"
		end
		-- a claim: they hold a province of our home country, or one we held lately
		local P = self.P
		local home = self:province_at(self.o_spawn_tile[a])
		local iso = if home > 0 then P.country[home] else ""
		local since = self.tick - self.dp.claim_s * TICK_RATE
		for p = 1, P.n do
			if self.p_holder[p] == b then
				if iso ~= "" and P.country[p] == iso then
					return "claim"
				end
				local prev = self.p_prev[p]
				if prev ~= nil and prev[1] == a and prev[2] >= since then
					return "claim"
				end
			end
		end
		return nil
	end

	local function provinces_of(self: any, id: number): { [number]: boolean }
		local out = {}
		for p = 1, self.P.n do
			if self.p_holder[p] == id then
				out[p] = true
			end
		end
		return out
	end

	local function start_war(self: any, a: number, b: number, cb_a: boolean)
		local k = key(a, b)
		if self.wars[k] ~= nil then
			return
		end
		local lo, hi = math.min(a, b), math.max(a, b)
		self.wars[k] = {
			a = lo,
			b = hi,
			since = self.tick,
			--- land each had taken from the other before it began (the score counts what comes after)
			base = { [lo] = took_by(self, lo, hi), [hi] = took_by(self, hi, lo) },
			prov = { [lo] = provinces_of(self, lo), [hi] = provinces_of(self, hi) },
			attacker = a,
			cb = cb_a,
		}
		self._dip_dirty = true
		self:ev({ Ev.WAR, a, b, if cb_a then 1 else 0 })
	end

	--- `a` declares war on `b`. Its pacts, its overlord and its vassals join `b`'s side; `a`'s vassals join `a`. With
	--- no reason: unrest and aggression for `a`.
	function C:declare_war(a: number, b: number): boolean
		if self.wars == nil or not realm(self, a) or not realm(self, b) or self:at_war(a, b) then
			return false
		end
		local cb = self:casus_belli(a, b)
		start_war(self, a, b, cb ~= nil)
		if cb == nil then
			self.o_unrest_add[a] += self.dp.nocb_unrest
			self.o_ae[a] += self.dp.nocb_ae
			self.o_prestige[a] = math.max(self.o_prestige[a] - self.dp.prestige_nocb, 0)
			self:msg(a, Defs.MSG_BAD, string.format("War on %s without a reason: your people grumble, the world remembers", self.o_name[b]))
		end
		self:msg(b, Defs.MSG_BAD, string.format("%s declares war on you", self.o_name[a]))
		-- who else joins: b's pact partners, its overlord and vassals; a's vassals
		local join_b = {}
		for _, x in self:allies_of(b) do
			table.insert(join_b, x)
		end
		local ov = self:overlord(b)
		if ov ~= 0 then
			table.insert(join_b, ov)
		end
		for v, o in self.vassal_of do
			if o == b then
				table.insert(join_b, v)
			end
		end
		table.sort(join_b)
		for _, x in join_b do
			if x ~= a and realm(self, x) and not self:allied(x, a) and self:overlord(a) ~= x and self:truce_until(x, a) == 0 then
				start_war(self, x, a, true)
				-- (an AI that joins turns on the aggressor: its targeting reads grudges)
				self:add_grudge(x, a, self.dp.join_grudge_s * TICK_RATE)
			end
		end
		local join_a = {}
		for v, o in self.vassal_of do
			if o == a then
				table.insert(join_a, v)
			end
		end
		table.sort(join_a)
		for _, v in join_a do
			if v ~= b and realm(self, v) and not self:allied(v, b) then
				start_war(self, v, b, true)
			end
		end
		return true
	end

	--- May `a` attack `b` now? Declares the war when it may. False (with a message to a person) during a truce, against
	--- one's overlord or vassal; an AI without a reason holds back most of the time.
	function C:may_attack(a: number, b: number): boolean
		if self.wars == nil or b == 0 or not realm(self, a) or self.o_kind[b] == Defs.KIND_TRIBE then
			return true
		end
		if self:at_war(a, b) then
			return true
		end
		local tu = self:truce_until(a, b)
		if tu > 0 then
			self:msg(a, Defs.MSG_INFO, string.format("A truce with %s holds for %ds more", self.o_name[b], math.ceil((tu - self.tick) / TICK_RATE)))
			return false
		end
		if self:overlord(a) == b or self:overlord(b) == a then
			self:msg(a, Defs.MSG_INFO, string.format("%s is bound to you by vassalage", self.o_name[b]))
			return false
		end
		-- (an AI holds back without a reason; a realm that wars without them draws it on itself, o_ae)
		if self.o_ai[a] == 1 and self:casus_belli(a, b) == nil and self.rng:randf() >= self.dp.ai_nocb_chance + self.o_ae[b] / 200 then
			return false
		end
		return self:declare_war(a, b)
	end

	--- A province's last holder, for claims.
	local prev_changed = C._on_province_changed
	function C:_on_province_changed(p: number, old: number, holder: number)
		prev_changed(self, p, old, holder)
		if self.wars == nil then
			return
		end
		if old ~= 0 then
			self.p_prev[p] = { old, self.tick }
		end
	end

	--- Land `id` has taken from `other` in their war.
	function C:war_took(id: number, other: number): number
		local w = self.wars and self.wars[key(id, other)]
		if w == nil then
			return 0
		end
		return took_by(self, id, other) - (w.base[id] or 0)
	end

	--- `id`'s war score against `other`, -100..100: land taken both ways against the smaller realm's, and troops.
	function C:war_score(id: number, other: number): number
		local w = self.wars and self.wars[key(id, other)]
		if w == nil then
			return 0
		end
		local mine, theirs = self:war_took(id, other), self:war_took(other, id)
		local base = math.max(math.min(self.o_tiles[id], self.o_tiles[other]), 200)
		local land = (mine - theirs) / base * 100
		local t1, t2 = self.o_troops[id] + 1, self.o_troops[other] + 1
		local troops = (t1 - t2) / math.max(t1, t2) * 25
		return math.clamp(land + troops, -100, 100)
	end

	--- Ends the war of `a` and `b` on `terms` (1 white, 2 provinces, 3 tribute, 4 vassal) with `winner` taking them.
	function C:make_peace(a: number, b: number, terms: number, winner: number)
		local k = key(a, b)
		local w = self.wars and self.wars[k]
		if w == nil then
			return
		end
		local loser = if winner == a then b else a
		self.wars[k] = nil
		self.truces[k] = self.tick + self.dp.truce_s * TICK_RATE
		self._dip_dirty = true
		-- the armies go home
		for _, at in self.attacks do
			if not at.dead and ((at.attacker == a and at.target == b) or (at.attacker == b and at.target == a)) then
				self:end_attack(at, true)
			end
		end
		local P = self.P
		local text = "white peace"
		if terms == 2 then
			local n = 0
			for p in w.prov[loser] or {} do
				if self.p_holder[p] == winner then
					self:handover(p, loser, winner)
					n += 1
				end
			end
			text = string.format("%d province%s ceded", n, if n == 1 then "" else "s")
		elseif terms == 3 then
			local g = math.floor(self.o_gold[loser] * self.dp.tribute_share)
			self.o_gold[loser] -= g
			self.o_gold[winner] += g
			text = string.format("%s gold in tribute", Defs.format_troops(g))
		elseif terms == 4 then
			self.vassal_of[loser] = winner
			-- (a vassal's own vassals pass to the overlord)
			for v, o in self.vassal_of do
				if o == loser then
					self.vassal_of[v] = winner
				end
			end
			text = "vassalage"
		end
		if terms > 1 then
			self:add_prestige(winner, self.dp.prestige_peace * (terms - 1))
		end
		self:ev({ Ev.PEACE, a, b, terms, winner })
		local line = string.format("Peace between %s and %s: %s", self.o_name[a], self.o_name[b], text)
		self:msg(a, Defs.MSG_INFO, line)
		self:msg(b, Defs.MSG_INFO, line)
		local _ = P
	end

	--- Prestige (Phase 6 reads it for the prestige victory): a share for ideas and traits.
	function C:add_prestige(id: number, amount: number)
		if self.o_prestige == nil or id <= 0 then
			return
		end
		self.o_prestige[id] += amount * math.max(1 + self:lev(id, "prestige"), 0.1)
	end

	--- Would AI `id` accept `terms` from `from`? From its war score, its standing toward `from` and the war's age.
	function C:ai_accepts(id: number, from: number, terms: number): boolean
		local ws = self:war_score(from, id)
		local w = self.wars[key(id, from)]
		local long = w ~= nil and self.tick - w.since > self.dp.weary_s * TICK_RATE
		local need = self.dp.peace_need[terms]
		local opinion = self:lev(from, "opinion") * 0.3 - self.o_ae[from] * 0.2
		if terms == 1 then
			-- white: unless it is winning well
			return -ws < need + (if long then 20 else 0) - opinion
		end
		if terms == 4 and self.o_tiles[id] > self.o_tiles[from] * self.dp.vassal_size then
			return false
		end
		return ws + opinion + (if long then 10 else 0) >= need
	end

	--- The peace intent: `id` offers `target` peace on `kind` ("white" / "provinces" / "tribute" / "vassal", `id` the
	--- winner of the terms). An AI answers at once; a person gets a request.
	function C:offer_peace(id: number, target: number, kind: string): boolean
		local terms = SimDiplomacy.TERM_INDEX[kind]
		local yield = SimDiplomacy.YIELD_INDEX[kind]
		if self.wars == nil or (terms == nil and yield == nil) or not self:at_war(id, target) then
			return false
		end
		-- (surrender: `target` wins the terms `id` yields)
		local winner = if yield ~= nil then target else id
		terms = terms or yield
		local person = self.o_kind[target] == Defs.KIND_HUMAN and self.o_ai[target] == 0 and self.o_bot[target] == 0 and self.o_left[target] == 0
		if person then
			local k = id * 1024 + target
			self.peace_req[k] = { id, target, terms, self.tick, winner }
			self:ev({ Ev.PEACE_REQ, id, target, terms + (if yield ~= nil then SimDiplomacy.YIELD else 0), self.tick })
			self:msg(id, Defs.MSG_INFO, string.format("Your terms went to %s", self.o_name[target]))
			return true
		end
		-- (an AI always takes a surrender: it loses nothing)
		if yield ~= nil or self:ai_accepts(target, id, terms) then
			self:make_peace(id, target, terms, winner)
			return true
		end
		self:msg(id, Defs.MSG_INFO, string.format("%s refuses: %s", self.o_name[target], SimDiplomacy.TERM_NAMES[terms]))
		return false
	end

	--- A person answers a peace request from `from`.
	function C:peace_reply(id: number, from: number, accept: boolean): boolean
		if self.peace_req == nil then
			return false
		end
		local k = from * 1024 + id
		local r = self.peace_req[k]
		if r == nil then
			return false
		end
		self.peace_req[k] = nil
		self:ev({ Ev.PEACE_REQ, from, id, 0, 0 })
		if accept and self:at_war(from, id) then
			self:make_peace(from, id, r[3], r[5] or from)
			return true
		end
		self:msg(from, Defs.MSG_INFO, string.format("%s refuses your terms", self.o_name[id]))
		return false
	end

	--- Once a second: aggression fades, truces end, vassals pay, requests expire, and a few AI realms think about peace.
	function C:_diplomacy_second()
		if self.wars == nil then
			return
		end
		local dp = self.dp
		for id = 1, self.owner_total do
			self.o_ae[id] *= dp.ae_decay
		end
		for _, k in self:_ordered_keys(self.truces) do
			if self.truces[k] <= self.tick then
				self.truces[k] = nil
				self._dip_dirty = true
			end
		end
		-- vassals pay their share each second
		for _, v in self:_ordered_keys(self.vassal_of) do
			local o = self.vassal_of[v]
			if self.o_alive[v] == 0 or self.o_alive[o] == 0 then
				self.vassal_of[v] = nil
				self._dip_dirty = true
			else
				local g = self.o_income[v] * dp.vassal_share
				self.o_gold[v] -= g
				self.o_gold[o] += g
			end
		end
		for _, k in self:_ordered_keys(self.peace_req) do
			local r = self.peace_req[k]
			if self.tick - r[4] > dp.request_s * TICK_RATE or not self:at_war(r[1], r[2]) then
				self.peace_req[k] = nil
				self:ev({ Ev.PEACE_REQ, r[1], r[2], 0, 0 })
			end
		end
		-- the AI: every few seconds a share of its realms at war weigh peace
		local stride = dp.ai_peace_stride
		local slot = (self.tick // TICK_RATE) % stride
		for _, k in self:_ordered_keys(self.wars) do
			local w = self.wars[k]
			for _, pair in { { w.a, w.b }, { w.b, w.a } } do
				local id, foe = pair[1], pair[2]
				if self.o_ai[id] == 1 and id % stride == slot and self.o_alive[id] == 1 then
					self:_ai_peace(id, foe)
				end
			end
		end
	end

	--- An AI realm at war with `foe`: a winner names its terms, a loser asks for white peace (a person gets the request).
	function C:_ai_peace(id: number, foe: number)
		local w = self.wars[key(id, foe)]
		if w == nil or self.tick - w.since < self.dp.ai_peace_after_s * TICK_RATE then
			return
		end
		local ws = self:war_score(id, foe)
		if ws <= -self.dp.ai_sue_at then
			-- losing: white peace, or the provinces if it must
			if self.o_ai[foe] == 1 then
				if self:ai_accepts(foe, id, 1) then
					self:make_peace(id, foe, 1, foe)
				else
					self:make_peace(id, foe, 2, foe)
				end
			elseif self.peace_req[id * 1024 + foe] == nil then
				self.peace_req[id * 1024 + foe] = { id, foe, 1, self.tick, foe }
				self:ev({ Ev.PEACE_REQ, id, foe, 1, self.tick })
			end
		elseif ws >= self.dp.ai_demand_at then
			local terms = if ws >= self.dp.peace_need[4] and self.o_tiles[foe] < self.o_tiles[id] * self.dp.vassal_size then 4 else 2
			if self.o_ai[foe] == 1 then
				if self:ai_accepts(foe, id, terms) then
					self:make_peace(id, foe, terms, id)
				end
			elseif self.peace_req[id * 1024 + foe] == nil then
				-- (winning against a person: it names its terms, and they may take them; players can be vassals too)
				self.peace_req[id * 1024 + foe] = { id, foe, terms, self.tick, id }
				self:ev({ Ev.PEACE_REQ, id, foe, terms, self.tick })
			end
		end
	end

	--- A realm falls: its wars, truces, vassal ties and requests go.
	function C:_diplomacy_eliminated(id: number)
		if self.wars == nil then
			return
		end
		for _, k in self:_ordered_keys(self.wars) do
			local w = self.wars[k]
			if w.a == id or w.b == id then
				self.wars[k] = nil
				self:ev({ Ev.PEACE, w.a, w.b, 0, 0 })
			end
		end
		for _, k in self:_ordered_keys(self.truces) do
			if k // 1024 == id or k % 1024 == id then
				self.truces[k] = nil
			end
		end
		self.vassal_of[id] = nil
		for _, v in self:_ordered_keys(self.vassal_of) do
			if self.vassal_of[v] == id then
				self.vassal_of[v] = nil
			end
		end
		self._dip_dirty = true
	end

	--- The diplomacy rows: wars { a, b, since, took_a, took_b, attacker, cb }, truces { a, b, until }, vassals { v, o }.
	function C:_diplomacy_rows(): { [string]: any }
		local wars, truces, vassals = {}, {}, {}
		if self.wars ~= nil then
			for _, k in self:_ordered_keys(self.wars) do
				local w = self.wars[k]
				table.insert(wars, { w.a, w.b, w.since, self:war_took(w.a, w.b), self:war_took(w.b, w.a), w.attacker, if w.cb then 1 else 0 })
			end
			for _, k in self:_ordered_keys(self.truces) do
				table.insert(truces, { k // 1024, k % 1024, self.truces[k] })
			end
			for _, v in self:_ordered_keys(self.vassal_of) do
				table.insert(vassals, { v, self.vassal_of[v] })
			end
		end
		return { w = wars, t = truces, v = vassals }
	end
end

return SimDiplomacy
