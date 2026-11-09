--!nonstrict
-- The clients' mirror of a depth match (docs/DEPTH_DESIGN.md): what GameState holds as `depth` when the snapshot has a
-- `depth` block. Loaded from the snapshot, kept by the delta's `dp` (h holders, r realms, k rulers, d diplomacy, a
-- armies, m ambitions) and the events Ev.RULER .. Ev.AMBITION. Read-only helpers for the interface.
--
--   ds.key                    "long" / "quick"
--   ds.P                      Core/Provinces of the map; ds.holder[p]
--   ds.realm[id]              { tax, unrest, mp, food, food_rate (a second), ptax, prestige }
--   ds.ruler[id]              { name, num, age, traits = { key... } }
--   ds.wars[key]              { a, b, since, took_a, took_b, attacker, cb }; ds.truces[key] = until tick; ds.vassal_of[v]
--   ds.armies[aid]            { aid, owner, troops, size, general, mode, stance, target, dest, tile, state, siege_p, siege_left }
--   ds.amb[id]                { { kind, arg, done }... } (kind: "unite" / "empire" / "city" / "treasury")
--   ds.peace_in[from]         { from, to, terms, tick }: offers to the local player
local Provinces = require("./Provinces")
local Ev = require("./Ev")
local Rulers = require("../Data/Rulers")

local DepthState = {}
DepthState.__index = DepthState

DepthState.TAX_KEYS = { "low", "fair", "high", "crushing" }
DepthState.TAX_NAMES = { "Low", "Fair", "High", "Crushing" }
DepthState.TERM_KEYS = { "white", "provinces", "tribute", "vassal" }
DepthState.TERM_NAMES = { "White peace", "Cede provinces", "Tribute", "Vassalage" }
--- An offer's words from where the local player stands: terms 1-4 the sender wins, 11-14 the sender yields.
function DepthState.offer_words(terms: number): string
	if terms > 10 then
		return ({ "", "they cede provinces", "they pay tribute", "they become your vassal" })[terms - 10] or "they yield"
	end
	return ({ "white peace", "you cede provinces", "you pay tribute", "you become their vassal" })[terms] or "peace"
end
--- Surrender terms the player can offer (they yield): intent kind and button words.
DepthState.YIELD_KEYS = { "concede", "pay", "submit" }
DepthState.YIELD_NAMES = { "Cede provinces", "Pay tribute", "Become vassal" }
DepthState.AMB_KINDS = { "unite", "empire", "city", "treasury" }
DepthState.STANCES = { "attack", "advance", "hold" }
DepthState.STATES = { "idle", "march", "siege", "home" }

local function key(a: number, b: number): number
	return if a < b then a * 1024 + b else b * 1024 + a
end
DepthState.key = key

--- A mirror for GameState `gs` from its snapshot's depth block `snap`.
function DepthState.new(gs: any, snap: { [string]: any }): any
	local self = setmetatable({}, DepthState)
	self.gs = gs
	self.key = snap.key
	self.P = if gs.map ~= nil then Provinces.for_map(gs.map) else nil
	self.holder = table.create(if self.P then self.P.n else 0, 0)
	self.realm = {}
	self.ruler = {}
	self.wars = {}
	self.truces = {}
	self.vassal_of = {}
	self.armies = {}
	self.amb = {}
	self.peace_in = {}
	self:_holders(snap.h or {})
	for _, r in snap.r or {} do
		self:_realm(r)
	end
	for _, r in snap.k or {} do
		self:_ruler(r)
	end
	if snap.d ~= nil then
		self:_diplomacy(snap.d)
	end
	for _, r in snap.a or {} do
		self:_army(r)
	end
	for _, r in snap.m or {} do
		self:_amb(r)
	end
	return self
end

function DepthState._holders(self, h: { number })
	for i = 1, #h, 2 do
		self.holder[h[i]] = h[i + 1]
	end
end

function DepthState._realm(self, r: { number })
	self.realm[r[1]] = { tax = r[2], unrest = r[3], mp = r[4], food = r[5], food_rate = (r[6] or 0) / 10, ptax = r[7] or 0, prestige = r[8] or 0 }
end

function DepthState._ruler(self, r: { any })
	local traits = {}
	for i = 5, 7 do
		local t = Rulers.TRAITS[r[i] or 0]
		if t ~= nil then
			table.insert(traits, t.key)
		end
	end
	self.ruler[r[1]] = { name = r[2], num = r[3], age = r[4], traits = traits }
end

function DepthState._diplomacy(self, d: { [string]: any })
	table.clear(self.wars)
	table.clear(self.truces)
	table.clear(self.vassal_of)
	for _, w in d.w or {} do
		self.wars[key(w[1], w[2])] = { a = w[1], b = w[2], since = w[3], took_a = w[4], took_b = w[5], attacker = w[6], cb = w[7] == 1 }
	end
	for _, t in d.t or {} do
		self.truces[key(t[1], t[2])] = t[3]
	end
	for _, v in d.v or {} do
		self.vassal_of[v[1]] = v[2]
	end
end

function DepthState._army(self, r: { number })
	if r[2] == 0 then
		self.armies[r[1]] = nil
		return
	end
	self.armies[r[1]] = {
		aid = r[1],
		owner = r[2],
		troops = r[3],
		size = r[4],
		general = r[5],
		mode = if r[6] == 1 then "front" else "march",
		stance = DepthState.STANCES[r[7]] or "hold",
		target = r[8],
		dest = r[9],
		tile = r[10],
		state = DepthState.STATES[r[11]] or "idle",
		siege_p = r[12],
		siege_left = r[13],
	}
end

function DepthState._amb(self, r: { number })
	local list = {}
	for i = 2, #r, 3 do
		table.insert(list, { DepthState.AMB_KINDS[r[i]] or "empire", r[i + 1], r[i + 2] == 1 })
	end
	self.amb[r[1]] = list
end

--- The delta's `dp`.
function DepthState.apply(self, dp: { [string]: any })
	if dp.h ~= nil then
		self:_holders(dp.h)
	end
	for _, r in dp.r or {} do
		self:_realm(r)
	end
	for _, r in dp.k or {} do
		self:_ruler(r)
	end
	if dp.d ~= nil then
		self:_diplomacy(dp.d)
	end
	for _, r in dp.a or {} do
		self:_army(r)
	end
	for _, r in dp.m or {} do
		self:_amb(r)
	end
end

--- The depth events (GameState hands them on).
function DepthState.event(self, e: { any })
	local k = e[1]
	if k == Ev.RULER then
		self:_ruler({ e[2], e[3], e[4], e[5], e[6], e[7], e[8] })
	elseif k == Ev.WAR then
		local kk = key(e[2], e[3])
		if self.wars[kk] == nil then
			self.wars[kk] = { a = math.min(e[2], e[3]), b = math.max(e[2], e[3]), since = self.gs.tick, took_a = 0, took_b = 0, attacker = e[2], cb = e[4] == 1 }
		end
	elseif k == Ev.PEACE then
		self.wars[key(e[2], e[3])] = nil
		-- (an offer between them is moot now)
		self.peace_in[e[2]] = nil
		self.peace_in[e[3]] = nil
	elseif k == Ev.PEACE_REQ then
		local me = self.gs.local_owner or 0
		if e[3] == me then
			self.peace_in[e[2]] = if e[4] > 0 then { from = e[2], to = e[3], terms = e[4], tick = e[5] } else nil
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Reads
-- ---------------------------------------------------------------------------------------------

function DepthState.at_war(self, a: number, b: number): boolean
	return self.wars[key(a, b)] ~= nil
end

--- Seconds of truce left between `a` and `b` (0: none).
function DepthState.truce_left(self, a: number, b: number): number
	local t = self.truces[key(a, b)]
	if t == nil then
		return 0
	end
	return math.max(0, (t - self.gs.tick) / 10)
end

function DepthState.overlord(self, id: number): number
	return self.vassal_of[id] or 0
end

--- The province of tile `t` (0: none).
function DepthState.province_at(self, t: number): number
	if self.P == nil or t < 0 then
		return 0
	end
	return Provinces.at(self.P, t)
end

--- How many provinces `id` holds.
function DepthState.held(self, id: number): number
	local n = 0
	for _, h in self.holder do
		if h == id then
			n += 1
		end
	end
	return n
end

--- Buildings standing in province `p` (all owners), from the mirror's structures.
function DepthState.slots_used(self, p: number): number
	local n = 0
	for _, s in self.gs.structures do
		if Provinces.at(self.P, s.tile) == p then
			n += 1
		end
	end
	return n
end

--- `id`'s war score against `other` as the Sim reckons it (SimDiplomacy.war_score), -100..100.
function DepthState.war_score(self, id: number, other: number): number
	local w = self.wars[key(id, other)]
	if w == nil then
		return 0
	end
	local mine = if w.a == id then w.took_a else w.took_b
	local theirs = if w.a == id then w.took_b else w.took_a
	local gs = self.gs
	local oi, oo = gs:get_owner(id), gs:get_owner(other)
	if oi == nil or oo == nil then
		return 0
	end
	local base = math.max(math.min(oi.tiles, oo.tiles), 200)
	local land = (mine - theirs) / base * 100
	local t1, t2 = (oi.troops or 0) + 1, (oo.troops or 0) + 1
	local troops = (t1 - t2) / math.max(t1, t2) * 25
	return math.clamp(land + troops, -100, 100)
end

--- The wars `id` is in: { { other, row } }, by the other's id.
function DepthState.wars_of(self, id: number): { { any } }
	local out = {}
	for _, w in self.wars do
		if w.a == id then
			table.insert(out, { w.b, w })
		elseif w.b == id then
			table.insert(out, { w.a, w })
		end
	end
	table.sort(out, function(x, y)
		return x[1] < y[1]
	end)
	return out
end

--- `id`'s armies, by aid.
function DepthState.armies_of(self, id: number): { any }
	local out = {}
	for _, ar in self.armies do
		if ar.owner == id then
			table.insert(out, ar)
		end
	end
	table.sort(out, function(x, y)
		return x.aid < y.aid
	end)
	return out
end

--- A ruler's name as shown: "Henry II".
function DepthState.ruler_title(self, id: number): string?
	local r = self.ruler[id]
	if r == nil then
		return nil
	end
	return Rulers.title(r.name, r.num)
end

--- An ambition in words (as the Sim words it, SimAmbitions.ambition_text).
function DepthState.ambition_text(self, a: { any }): string
	local kind, arg = a[1], a[2]
	if kind == "unite" then
		return "Unite your homeland"
	elseif kind == "empire" then
		return string.format("Hold %d provinces", arg)
	elseif kind == "city" then
		return "Hold " .. (if self.P ~= nil then self.P.name[arg] or "the great city" else "the great city")
	end
	local g = arg or 0
	return if g >= 1000000 then string.format("Amass %sM gold", tostring(math.floor(g / 100000) / 10)) else string.format("Amass %dK gold", math.floor(g / 1000))
end

return DepthState
