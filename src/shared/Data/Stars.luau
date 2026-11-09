--!strict
-- Renown (saved as `stars`, an internal name kept so saves load): what a war pays a ruler, spent at the War College
-- (Data/Arsenal). It pays for what this game is about, line by line:
--
--   ages       a rate a minute alive, set by the last age reached (AGE_RATE: 10, 14, 18, 22): a war that reaches
--              the Reckoning pays more for every minute of it. At least FLOOR for a ruler who stayed to the end;
--              half, and no floor, for one who walked out of a war that goes on.
--   ground     40 x most land held, in fair shares    (a share = the map's land / the nations and players)
--   rivals     30 a nation or player beaten           (clans don't count: there are hundreds)
--   doctrines  30 a doctrine drafted                  (at most one a draft)
--   landmarks  25 x most landmarks held at once
--   standing   10 a minute x standing score           score = (1 - (place - 1) / (field - 1))^1.5;
--                                                     not for a ruler who walked out
--   triumph    120 + 10 a minute                      the winner
--
-- An average seat is paid about 1,000 for a war, and a judged mix of wars about 3,000 an hour against about 2,900 from
-- the formula this replaced, so the War College's pace holds (tests/stars.luau works them through). Every line is rounded to 10 (at least 10 when it pays at all). A
-- ruler who never planted a banner gets nothing. A war alone pays a share of this by difficulty (MODE_MULT: it runs
-- on the player's own device against the AI).
--
--   Stars.payout(result, mode) -> { lines = { { key, amount } }, total }
--   Stars.sanitize(report, real_minutes) -> result   a client's solo report, made safe
--   Stars.solo_cap(real_minutes)                     the most a solo match of that length may pay
--   Stars.Tracker.new(sim)                           follows a running Sim for its humans' results
local IS_ROBLOX = typeof(game) == "Instance"
local Core: any = if IS_ROBLOX then (game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Core else nil
local Defs: any = if IS_ROBLOX then require(Core.Defs) else require("../Core/Defs")
local Ev: any = if IS_ROBLOX then require(Core.Ev) else require("../Core/Ev")

local Stars = {}

Stars.NAME = "Renown"
--- The least the ages line pays a ruler who stayed to the end.
Stars.FLOOR = 60
--- A minute alive pays this, by the last age reached (Data/Eras: Dawn, Expansion, Conflict, Reckoning).
Stars.AGE_RATE = { 10, 14, 18, 22 }
--- What's left of the ages line for a ruler who walked out of a war that goes on.
Stars.LEFT_SHARE = 0.5
Stars.PER_SHARE = 40
Stars.PER_RIVAL = 30
Stars.PER_DOCTRINE = 30
Stars.PER_LANDMARK = 25
Stars.PLACE_RATE = 10
--- How steeply standing falls away from first place (1: a straight line).
Stars.PLACE_CURVE = 1.5
Stars.TRIUMPH_BASE = 120
Stars.TRIUMPH_RATE = 10
Stars.QUANTUM = 10
--- What a mode pays of the formula. Alone runs on the player's device against the AI: Recruit, Veteran, Warlord.
-- (release 2026-11-07: Warlord alone paid 105 %, more than a public war against people; alone never out-earns public)
Stars.MODE_MULT = { public = 1.0, solo0 = 0.45, solo1 = 0.7, solo2 = 0.9 }
--- A solo match's result is the client's word: its Renown never exceeds this much per real minute (the server's
--- clock). Generous for an honest fast win, a ceiling for a made-up one.
-- (release audit 2026-11-07: 200 let solo pay about twice a public war an hour, and a made-up report 12,000 an hour;
-- 100 still pays an honest fast win in full: a won solo war earns about 1,000-1,500 in its 10-15 minutes)
Stars.SOLO_CAP_PER_MIN = 100
--- Sanity bounds for a result.
Stars.MAX_MINUTES = 240
Stars.MAX_KILLS = 200
Stars.MAX_FIELD = 1024
Stars.MAX_AGES = #Stars.AGE_RATE
--- One draft an age, three in all (Data/Eras.draft_of, Data/Doctrines.TIERS).
Stars.MAX_DOCTRINES = 3
Stars.MAX_LANDMARKS = 24

Stars.LINES = { "ages", "ground", "rivals", "doctrines", "landmarks", "standing", "triumph" }
Stars.LABELS = {
	ages = "Ages lived",
	ground = "Ground held",
	rivals = "Rivals beaten",
	doctrines = "Doctrines drafted",
	landmarks = "Landmarks held",
	standing = "Final standing",
	triumph = "Triumph",
	general = "Charter stipend",
	warband = "Fought beside a friend",
	rest = "The rest of your war",
}

--- A public war fought with someone from your warband pays this much more (release 2026-11-07: a reason to bring a
--- friend; the server checks the party, Rewards.pay).
Stars.WARBAND_BONUS = 0.10

--- The warband line for a payout of `total`: WARBAND_BONUS of it in whole QUANTUMs (0 when it rounds away).
function Stars.warband_bonus(total: number): number
	return math.floor(math.max(0, total) * Stars.WARBAND_BONUS / Stars.QUANTUM) * Stars.QUANTUM
end

export type Result = {
	spawned: boolean,
	left: boolean,
	won: boolean,
	minutes: number,
	shares: number,
	kills: number,
	place: number,
	field: number,
	--- the last age reached, 1..MAX_AGES (a result without one: the Dawn)
	ages: number?,
	--- doctrines drafted
	doctrines: number?,
	--- most landmarks held at once
	landmarks: number?,
}

local function quantum(x: number): number
	if x <= 0 then
		return 0
	end
	return math.max(Stars.QUANTUM, math.floor(x / Stars.QUANTUM + 0.5) * Stars.QUANTUM)
end

function Stars.place_score(place: number, field: number): number
	if field <= 1 then
		return 1
	end
	local s = math.clamp(1 - (place - 1) / (field - 1), 0, 1)
	return s ^ Stars.PLACE_CURVE
end

--- The Renown `r` pays in `mode` ("public" / "solo0".."solo2").
function Stars.payout(r: Result, mode: string?): { lines: { { any } }, total: number }
	local lines: { { any } } = {}
	local total = 0
	if not r.spawned then
		return { lines = lines, total = 0 }
	end
	local mult = Stars.MODE_MULT[mode or "public"] or 1.0
	local minutes = math.clamp(r.minutes, 0, Stars.MAX_MINUTES)
	local function add(key: string, amount: number)
		local a = quantum(amount * mult)
		if a > 0 then
			table.insert(lines, { key, a })
			total += a
		end
	end
	local age = math.clamp(math.floor(r.ages or 1), 1, Stars.MAX_AGES)
	local lived = Stars.AGE_RATE[age] * minutes
	add("ages", if r.left then lived * Stars.LEFT_SHARE else math.max(lived, Stars.FLOOR))
	add("ground", Stars.PER_SHARE * math.max(r.shares, 0))
	add("rivals", Stars.PER_RIVAL * math.max(r.kills, 0))
	add("doctrines", Stars.PER_DOCTRINE * math.clamp(r.doctrines or 0, 0, Stars.MAX_DOCTRINES))
	add("landmarks", Stars.PER_LANDMARK * math.clamp(r.landmarks or 0, 0, Stars.MAX_LANDMARKS))
	if not r.left then
		add("standing", Stars.PLACE_RATE * Stars.place_score(r.place, r.field) * minutes)
		if r.won then
			add("triumph", Stars.TRIUMPH_BASE + Stars.TRIUMPH_RATE * minutes)
		end
	end
	return { lines = lines, total = total }
end

--- The most a solo match that really lasted `real_minutes` may pay. Nothing without the time
--- passing: restarting a match over and over earns nothing.
function Stars.solo_cap(real_minutes: number): number
	return math.floor(Stars.SOLO_CAP_PER_MIN * math.max(real_minutes, 0))
end

local function num(v: any, lo: number, hi: number): number
	if type(v) ~= "number" or v ~= v then
		return lo
	end
	return math.clamp(v, lo, hi)
end

--- A client's solo result made safe: every field typed and bounded, and no longer than the match
--- really lasted on the server's clock.
function Stars.sanitize(report: any, real_minutes: number): Result
	local rep = if type(report) == "table" then report else {}
	local field = math.floor(num(rep.field, 1, Stars.MAX_FIELD))
	local ages = math.floor(num(rep.ages, 1, Stars.MAX_AGES))
	return {
		spawned = rep.spawned == true,
		left = rep.left == true,
		won = rep.won == true and rep.left ~= true,
		minutes = num(rep.minutes, 0, math.min(Stars.MAX_MINUTES, math.max(real_minutes, 0))),
		shares = num(rep.shares, 0, field),
		kills = math.floor(num(rep.kills, 0, math.min(field, Stars.MAX_KILLS))),
		place = math.floor(num(rep.place, 1, field)),
		field = field,
		ages = ages,
		-- (a draft opens each age: no more doctrines than ages reached)
		doctrines = math.floor(num(rep.doctrines, 0, math.min(ages, Stars.MAX_DOCTRINES))),
		landmarks = math.floor(num(rep.landmarks, 0, Stars.MAX_LANDMARKS)),
	}
end

-- =============================================================================================
-- Tracker: a running Sim's results
-- =============================================================================================
-- Fed after every Sim step (step(delta.ev)): the peak land of each watched human, the nations and
-- players each one conquered, the order the field fell in, the age each reached and the most landmarks each held
-- at once. `field` = the nations and players that took part (clans are scenery).

local Tracker = {}
Tracker.__index = Tracker
Stars.Tracker = Tracker

local KIND_TRIBE = Defs.KIND_TRIBE
local PHASE_PLAYING = Defs.PHASE_PLAYING
local PHASE_OVER = Defs.PHASE_OVER
local TICKS_PER_MINUTE = Defs.TICK_RATE * 60

function Tracker.new(sim: any)
	local self = setmetatable({}, Tracker)
	self.sim = sim
	--- owner id -> { start, peak, kills, out_tick, place, age, landmarks, doc_base }
	self.seats = {} :: { [number]: any }
	self.field = 0
	--- nations and players still standing
	self.live = 0
	self._counted = false
	return self
end

--- Counts the field once the match is being played (nations and players with land).
function Tracker._count(self: any)
	local sim = self.sim
	if self._counted or sim.phase < PHASE_PLAYING then
		return
	end
	self._counted = true
	local n = 0
	for id = 1, sim.owner_total do
		if sim.o_kind[id] ~= KIND_TRIBE and sim.o_alive[id] == 1 and sim.o_spawned[id] == 1 then
			n += 1
		end
	end
	self.field = math.max(n, 1)
	self.live = n
	for _, seat in self.seats do
		seat.start = math.max(seat.start, sim.tick)
	end
end

--- Follow human `id` from now on (a second call keeps what it has).
function Tracker.watch(self: any, id: number)
	if id <= 0 or self.seats[id] ~= nil then
		return
	end
	local sim = self.sim
	self.seats[id] = {
		start = sim.tick,
		peak = sim.o_tiles[id] or 0,
		kills = 0,
		out_tick = nil,
		place = nil,
		age = sim.era or 1,
		landmarks = 0,
		doc_base = 0,
	}
	if self._counted and sim.o_spawned[id] ~= 1 then
		-- a late joiner makes the field one bigger once it lands (see step)
		self.seats[id].late = true
	end
end

function Tracker.unwatch(self: any, id: number)
	self.seats[id] = nil
end

--- A takeover: the player who was `old` commands `new` from now on — a new life, counted from here
--- (the land it starts with is not the player's doing: the peak starts at 0 above it).
function Tracker.adopt(self: any, old: number, new: number)
	self.seats[old] = nil
	local sim = self.sim
	local docs = if sim.o_doc ~= nil then sim.o_doc[new] else nil
	self.seats[new] = {
		start = sim.tick,
		peak = 0,
		base = sim.o_tiles[new] or 0,
		kills = 0,
		out_tick = nil,
		place = nil,
		age = sim.era or 1,
		landmarks = 0,
		-- (the doctrines it already holds are not the player's doing either)
		doc_base = if docs ~= nil then #docs else 0,
	}
end

--- After every Sim step, with the step's events.
function Tracker.step(self: any, events: { { any } }?)
	local sim = self.sim
	self:_count()
	if not self._counted then
		return
	end
	local o_tiles = sim.o_tiles
	for id, seat in self.seats do
		if seat.late and sim.o_spawned[id] == 1 then
			seat.late = nil
			seat.start = sim.tick
			self.field += 1
			self.live += 1
		end
		local t = (o_tiles[id] or 0) - (seat.base or 0)
		if t > seat.peak then
			seat.peak = t
		end
		if seat.out_tick == nil then
			seat.age = math.max(seat.age, sim.era or 1)
			-- (Sim.landmark_held is refreshed once a second: Core/SimDoctrines)
			local held = if sim.landmark_held ~= nil then sim.landmark_held[id] else nil
			if held ~= nil then
				local n = 0
				for _, c in held do
					n += c
				end
				if n > seat.landmarks then
					seat.landmarks = n
				end
			end
		end
	end
	if events == nil then
		return
	end
	for _, e in events do
		if e[1] == Ev.OWNER_OUT then
			local id, killer = e[2], e[3]
			if sim.o_kind[id] ~= KIND_TRIBE then
				local seat = self.seats[id]
				if seat ~= nil and seat.out_tick == nil then
					seat.out_tick = sim.tick
					seat.place = math.max(self.live, 1)
				end
				self.live = math.max(self.live - 1, 0)
				local ks = self.seats[killer]
				if ks ~= nil and killer ~= id then
					ks.kills += 1
				end
			end
		end
	end
end

--- True once `id`'s result is final (it fell, or the match is over).
function Tracker.final(self: any, id: number): boolean
	local seat = self.seats[id]
	return seat ~= nil and (seat.out_tick ~= nil or self.sim.phase == PHASE_OVER)
end

--- `id`'s result so far; `left` = the player is leaving a match that goes on.
function Tracker.result(self: any, id: number, left: boolean?): Result
	local sim = self.sim
	local seat = self.seats[id]
	if seat == nil or not self._counted or sim.o_spawned[id] ~= 1 then
		return {
			spawned = false,
			left = left == true,
			won = false,
			minutes = 0,
			shares = 0,
			kills = 0,
			place = 1,
			field = 1,
			ages = 1,
			doctrines = 0,
			landmarks = 0,
		}
	end
	local field = math.max(self.field, 1)
	local place = seat.place
	if place == nil then
		-- still standing: ranked by land among the nations and players still standing
		place = 1
		local mine = sim.o_tiles[id] or 0
		for o = 1, sim.owner_total do
			if o ~= id and sim.o_kind[o] ~= KIND_TRIBE and sim.o_alive[o] == 1 and (sim.o_tiles[o] or 0) > mine then
				place += 1
			end
		end
	end
	local land = if sim.map ~= nil then sim.map.land_count else 0
	local share = math.max(land, 1) / field
	local gone = left == true and seat.out_tick == nil and sim.phase ~= PHASE_OVER
	return {
		spawned = true,
		left = gone,
		-- (a team game: everyone on the winning team won)
		won = not gone
			and sim.phase == PHASE_OVER
			and (sim.winner == id or ((sim.winner_team or 0) ~= 0 and sim.o_team ~= nil and sim.o_team[id] == sim.winner_team)),
		minutes = math.max(0, (seat.out_tick or sim.tick) - seat.start) / TICKS_PER_MINUTE,
		shares = seat.peak / share,
		kills = seat.kills,
		place = math.min(place, field),
		field = field,
		ages = math.clamp(seat.age, 1, Stars.MAX_AGES),
		doctrines = math.clamp(
			#(if sim.o_doc ~= nil then sim.o_doc[id] or {} else {}) - (seat.doc_base or 0),
			0,
			Stars.MAX_DOCTRINES
		),
		landmarks = math.clamp(seat.landmarks, 0, Stars.MAX_LANDMARKS),
	}
end

return Stars
