--!nonstrict
-- Depth Phase 3 (docs/DEPTH_DESIGN.md): rulers and their traits, and the depth levers of national ideas and techs.
-- Every realm (players, nations, bot players; not tribes) has a ruler { name, num (regnal number), age, traits, since }:
-- a year passes every `year_s` seconds; from Data/Rulers.DEATH_FROM each year may be the last, and an heir follows (a
-- new name, new traits, one kept sometimes, a jolt of unrest). Clients hear it as Ev.RULER.
--
-- The levers: a realm's ideas and techs (its doctrine keys, Data/Doctrines) and its ruler's traits (Data/Rulers)
-- multiply gold, cap, attack, defence, regrowth, trade and refunds (through _depth_mults), and sum the depth levers
-- (unrest, food, manpower, provinces allowed, fort, supply, general, siege, opinion, prestige), read with `lev`.
local Defs = require("./Defs")
local Ev = require("./Ev")
local Rulers = require("../Data/Rulers")
local Doctrines = require("../Data/Doctrines")

local SimRulers = {}

local TICK_RATE = Defs.TICK_RATE
--- bumped whenever any ruler changes (the levers' cache key)
local r_version = 0

function SimRulers.install(C: any)
	function C:_init_rulers()
		if self.depth == nil then
			return
		end
		--- owner id -> { name, num, age, traits = { key... }, year_at (tick of the next birthday) }
		self.o_ruler = {}
		--- owner id -> name -> times it was used (regnal numbers)
		self._regnal = {}
		--- owner id -> lever -> value, refreshed with the multipliers
		self.o_lev = {}
	end

	--- The depth lever `lever` of `id`: its ideas and techs, and its ruler's traits, summed.
	function C:lev(id: number, lever: string): number
		local l = self.o_lev and self.o_lev[id]
		if l == nil then
			return 0
		end
		return l[lever] or 0
	end

	local function pick_traits(self: any, keep: string?): { string }
		local n = if self.rng:randf() < Rulers.THIRD_TRAIT then 3 else 2
		local out = {}
		local banned = {}
		if keep ~= nil then
			table.insert(out, keep)
			banned[keep] = true
			local foe = Rulers.BY_KEY[keep].foe
			if foe ~= nil then
				banned[foe] = true
			end
		end
		local tries = 0
		while #out < n and tries < 60 do
			tries += 1
			local t = Rulers.TRAITS[self.rng:randi_range(1, #Rulers.TRAITS)]
			if not banned[t.key] then
				table.insert(out, t.key)
				banned[t.key] = true
				if t.foe ~= nil then
					banned[t.foe] = true
				end
			end
		end
		return out
	end

	local function new_name(self: any, id: number): (string, number)
		local P = self.P
		local home = self:province_at(self.o_spawn_tile[id])
		local iso = if home > 0 then P.country[home] else ""
		local pool = Rulers.pool(iso, self.period ~= nil)
		local name = pool[self.rng:randi_range(1, #pool)]
		local used = self._regnal[id]
		if used == nil then
			used = {}
			self._regnal[id] = used
		end
		used[name] = (used[name] or 0) + 1
		return name, used[name]
	end

	local function announce(self: any, id: number, cause: number)
		local r = self.o_ruler[id]
		local t = r.traits
		self:ev({ Ev.RULER, id, r.name, r.num, r.age, Rulers.INDEX[t[1]] or 0, Rulers.INDEX[t[2]] or 0, Rulers.INDEX[t[3]] or 0, cause })
	end

	--- `id`'s first ruler (when it lands), or its heir (`heir`: the old ruler died).
	function C:_crown_ruler(id: number, heir: boolean)
		local old = self.o_ruler[id]
		local keep = nil
		if heir and old ~= nil and self.rng:randf() < Rulers.INHERIT then
			keep = old.traits[self.rng:randi_range(1, #old.traits)]
		end
		local name, num = new_name(self, id)
		local span = if heir then Rulers.HEIR_AGE else Rulers.FIRST_AGE
		self.o_ruler[id] = {
			name = name,
			num = num,
			age = self.rng:randi_range(span[1], span[2]),
			traits = pick_traits(self, keep),
			year_at = self.tick + self.dp.year_s * TICK_RATE,
		}
		if heir then
			self.o_unrest_add[id] += Rulers.SUCCESSION_UNREST
			local r = self.o_ruler[id]
			self:msg(id, Defs.MSG_BAD, string.format("%s has died. %s takes the throne", Rulers.title(old.name, old.num), Rulers.title(r.name, r.num)))
			self:_on_succession(id)
		end
		announce(self, id, if heir then 1 else 0)
		-- (refreshed with the rest at the end of the tick: hundreds of first rulers come on one tick)
		self._mults_dirty = true
		r_version += 1
	end

	--- Hook: `id` has a new ruler (later phases: prestige, diplomacy).
	function C:_on_succession(_id: number) end

	--- Once a second: rulers for realms that landed, birthdays, and deaths.
	function C:_rulers_second()
		if self.o_ruler == nil then
			return
		end
		local tick = self.tick
		local year = self.dp.year_s * TICK_RATE
		for id = 1, self.owner_total do
			if self.o_alive[id] == 0 or self.o_spawned[id] == 0 or self.o_kind[id] == Defs.KIND_TRIBE then
				continue
			end
			local r = self.o_ruler[id]
			if r == nil then
				self:_crown_ruler(id, false)
			elseif tick >= r.year_at then
				r.year_at += year
				r.age += 1
				if r.age >= Rulers.DEATH_FROM then
					local risk = Rulers.DEATH_BASE + (r.age - Rulers.DEATH_FROM) * Rulers.DEATH_PER_YEAR + Rulers.sum(r.traits, "death")
					if r.age >= Rulers.DEATH_AT or self.rng:randf() < risk then
						self:_crown_ruler(id, true)
						continue
					end
				end
				self:_ruler_row(id)
			end
		end
	end

	--- The ruler row of `id` for the clients' delta (`dp.k`): id, name, num, age, trait indices.
	function C:_ruler_row(id: number)
		local r = self.o_ruler[id]
		if r == nil then
			return
		end
		local t = r.traits
		local d = self.d_ruler
		if d == nil then
			d = {}
			self.d_ruler = d
		end
		d[#d + 1] = { id, r.name, r.num, r.age, Rulers.INDEX[t[1]] or 0, Rulers.INDEX[t[2]] or 0, Rulers.INDEX[t[3]] or 0 }
	end

	--- Every ruler (a snapshot).
	function C:_ruler_rows(): { { any } }
		local out = {}
		if self.o_ruler == nil then
			return out
		end
		for id = 1, self.owner_total do
			local r = self.o_ruler[id]
			if r ~= nil and self.o_alive[id] == 1 then
				local t = r.traits
				table.insert(out, { id, r.name, r.num, r.age, Rulers.INDEX[t[1]] or 0, Rulers.INDEX[t[2]] or 0, Rulers.INDEX[t[3]] or 0 })
			end
		end
		return out
	end

	--- The depth multipliers, part 2: the ruler's traits and the realm's ideas (their summed levers cached in o_lev).
	local prev_mults = C._depth_mults
	function C:_depth_mults(id: number, gold: number, cap: number, atk: number, def: number, regen: number)
		gold, cap, atk, def, regen = prev_mults(self, id, gold, cap, atk, def, regen)
		if self.o_ruler == nil then
			return gold, cap, atk, def, regen
		end
		local r = self.o_ruler[id]
		local traits = if r ~= nil then r.traits else {}
		gold *= math.max(1.0 + Rulers.sum(traits, "gold"), 0.2)
		cap *= math.max(1.0 + Rulers.sum(traits, "cap"), 0.2)
		atk *= math.max(1.0 + Rulers.sum(traits, "atk"), 0.2)
		def *= math.max(1.0 + Rulers.sum(traits, "def"), 0.2)
		regen *= math.max(1.0 + Rulers.sum(traits, "regen"), 0.2)
		local keys = self.o_doc[id] or {}
		local l = self.o_lev[id]
		if l == nil then
			l = {}
			self.o_lev[id] = l
		end
		-- (the summed levers change only with a pick or a new ruler: cached by both)
		local sig = #keys * 1000003 + (if r ~= nil then (r.num or 0) * 101 + #r.name else 0)
		if l._sig ~= sig or l._r ~= r then
			l._sig = sig
			l._r = r
			for _, lever in Doctrines.DEPTH_LEVERS do
				l[lever] = Doctrines.sum(keys, lever) + Rulers.sum(traits, lever)
			end
		end
		return gold, cap, atk, def, regen
	end

	--- Ideas, techs and traits move unrest.
	local prev_unrest = C._unrest_extra
	function C:_unrest_extra(id: number): number
		return prev_unrest(self, id) + self:lev(id, "unrest")
	end
end

return SimRulers
