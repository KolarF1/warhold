--!nonstrict
-- What happened in this match, from the local player's side (Conquer the World's own): the land over time and the
-- moments worth remembering, for the War Report, and the counts a match report needs (Data/Progress). It only
-- listens to the mirror; nothing here touches the match.
--
--   log:reset(state)                 a new match
--   log:<on_*>(...)                  fed by UIRoot from the mirror's signals
--   log:report(won, extras)          the match report so far
local UICtx = require("./UICtx")
local Defs = UICtx.core("Defs")

local MatchLog = {}
MatchLog.__index = MatchLog

--- A sample of the land every this many ticks; the list halves itself past MAX_SAMPLES.
MatchLog.SAMPLE_TICKS = 50
MatchLog.MAX_SAMPLES = 96
MatchLog.MAX_MOMENTS = 40

function MatchLog.new(ctx: any)
	local self = setmetatable({}, MatchLog)
	self.ctx = ctx
	self:reset(nil)
	return self
end

function MatchLog.reset(self, state: any)
	self.state = state
	self.samples = {} :: { { number } } -- { seconds, my share, the leader's share }
	self.moments = {} :: { { any } } -- { seconds, text, good }
	self.step = MatchLog.SAMPLE_TICKS
	self.next_tick = 0
	self.builds = 0
	self.nukes = 0
	self.edicts = 0
	self.nemeses = 0
	self.events = 0
	self.landmarks = 0
	self.eliminated_at = nil
	self.was_nemesis = 0
	self.last_out = 0
	self.last_killer = 0
	self.lm_poll = 0
	--- Seconds into the match this life began (a takeover starts a new one: MatchLog.new_life).
	self.life_from = 0
end

--- A takeover's new life (solo): what the career counts from here is this life's alone. The first life's counts were
--- reported when it fell, so they start again from zero, and so does its clock. (The chronicle and samples go on.)
--- (release review 2026-11-07: the second report counted the first life again)
function MatchLog.new_life(self)
	self.builds = 0
	self.nukes = 0
	self.edicts = 0
	self.nemeses = 0
	self.events = 0
	self.landmarks = 0
	self.eliminated_at = nil
	self.life_from = self:_secs()
end

function MatchLog._secs(self): number
	return self.ctx:match_seconds()
end

function MatchLog.moment(self, text: string, good: boolean?)
	if #self.moments < MatchLog.MAX_MOMENTS then
		table.insert(self.moments, { self:_secs(), text, good == true })
	end
end

--- Every mirror tick.
function MatchLog.on_tick(self, tick: number)
	local s, me = self.state, self.ctx:me()
	if s == nil or me == 0 or s.phase ~= Defs.PHASE_PLAYING then
		return
	end
	if tick >= self.next_tick then
		self.next_tick = tick + self.step
		local top = 0.0
		for id, o in s.owners do
			if o.kind ~= Defs.KIND_TRIBE and o.alive then
				top = math.max(top, s:land_share(id))
			end
		end
		table.insert(self.samples, { self:_secs(), s:land_share(me), top })
		if #self.samples > MatchLog.MAX_SAMPLES then
			local kept = {}
			for i = 1, #self.samples, 2 do
				table.insert(kept, self.samples[i])
			end
			self.samples = kept
			self.step *= 2
		end
		self:_count_landmarks(s, me)
	end
end

function MatchLog._count_landmarks(self, s: any, me: number)
	local SimLandmarks = UICtx.core("SimLandmarks")
	if self._sites_map ~= s.map then
		self._sites_map = s.map
		self._sites = SimLandmarks.sites(s.map)
	end
	local n = 0
	for _, site in self._sites do
		if s:tile_owner(site.tile) == me then
			n += 1
		end
	end
	if n > self.landmarks then
		self.landmarks = n
		if n >= 3 then
			self:moment(string.format("You held %d landmarks at once", n), true)
		end
	end
end

function MatchLog.on_structure(self, sid: number)
	local s = self.state
	local st = s ~= nil and s.structures[sid]
	if st and st.owner == self.ctx:me() then
		self.builds += 1
	end
end

function MatchLog.on_nuke(self, uid: number)
	local s = self.state
	local n = s ~= nil and s.nukes[uid]
	if n and n.owner == self.ctx:me() then
		self.nukes += 1
		if self.nukes == 1 then
			self:moment("You launched your first " .. UICtx.data("PeriodTech").word("warhead"), false)
		end
	end
end

function MatchLog.on_edict(self, owner: number)
	if owner == self.ctx:me() then
		self.edicts += 1
	end
end

function MatchLog.on_world_event(self, index: number)
	self.events += 1
	local d = UICtx.data("WorldEvents").LIST[index]
	if d ~= nil then
		self:moment(d.name, d.good)
	end
end

function MatchLog.on_era(self, era: number)
	local name = UICtx.data("Eras").NAMES[era]
	if name ~= nil then
		self:moment("The " .. name .. " began", true)
	end
end

function MatchLog.on_eliminated(self, id: number, killer: number)
	self.last_out, self.last_killer = id, killer
	local s, me = self.state, self.ctx:me()
	if s == nil or me == 0 then
		return
	end
	if id == me then
		self.eliminated_at = self:_secs()
		self:moment(if killer > 0 then "You fell to " .. s:owner_name(killer) else "You fell", false)
	elseif killer == me and s.owners[id] ~= nil and s.owners[id].kind ~= Defs.KIND_TRIBE then
		self:moment("You brought down " .. s:owner_name(id), true)
	end
end

function MatchLog.on_nemesis(self, person: number, nation: number)
	local s, me = self.state, self.ctx:me()
	if s == nil or person ~= me then
		return
	end
	if nation > 0 then
		self.was_nemesis = nation
		self:moment(s:owner_name(nation) .. " became your nemesis", false)
	else
		if self.was_nemesis == self.last_out and self.last_killer == me then
			self.nemeses += 1
			self:moment("You slew your nemesis", true)
		end
		self.was_nemesis = 0
	end
end

--- The Chronicle's timeline: one entry per age of this match. Pure. `starts`: the match's era starts in ticks since play
--- (nil: the defaults); `samples`: this log's { seconds, my share, the leader's share }; `picks`: draft -> doctrine key;
--- `end_s`: seconds into play the story ended. Each entry: { era, name, roman, reached, start_s, held, best, doctrine }.
--- `held`: the land at the age's end (or when the story ended); nil without a sample in that age.
function MatchLog.chronicle(starts: { number }?, samples: { { number } }, picks: { [number]: string }, end_s: number): { any }
	local Eras = UICtx.data("Eras")
	local Doctrines = UICtx.data("Doctrines")
	local s = starts or Eras.DEFAULT
	local tick_rate = Defs.TICK_RATE
	local out = {}
	for i, name in Eras.NAMES do
		local doc = Doctrines.BY_KEY[picks[Eras.draft_of(i, s)] or ""]
		out[i] = {
			era = i,
			name = name,
			roman = ({ "I", "II", "III", "IV" })[i],
			start_s = s[i] / tick_rate,
			reached = end_s * tick_rate >= s[i],
			held = nil,
			best = nil,
			doctrine = if doc ~= nil and end_s * tick_rate >= s[i] then doc.name else nil,
		}
	end
	for _, sm in samples do
		local age = out[Eras.index(sm[1] * tick_rate, s)]
		if age ~= nil then
			age.held = sm[2]
			age.best = math.max(age.best or 0.0, sm[2])
		end
	end
	return out
end

--- The match report so far (Data/Progress).
function MatchLog.report(self, won: boolean, extras: { [string]: any }): { [string]: any }
	local s, me = self.state, self.ctx:me()
	local secs = math.max(0, (self.eliminated_at or self:_secs()) - (self.life_from or 0))
	local drafts = 0
	if s ~= nil and me ~= 0 then
		for _, row in pairs(s.doctrine[me] or {}) do
			if row[6] >= 1 then
				drafts += 1
			end
		end
	end
	-- (Data/Progress keeps these two for the title's greeting)
	local Eras = UICtx.data("Eras")
	local played = if s ~= nil and (s.playing_since or -1) >= 0 then s.tick - s.playing_since else 0
	local rival = if s ~= nil and self.was_nemesis > 0 then s:owner_name(self.was_nemesis) else nil
	local r = {
		age = if s ~= nil and s.eras ~= nil then Eras.index(played, s.eras) else nil,
		rival = rival,
		seconds = secs,
		share = if s ~= nil and me ~= 0 then s:land_share(me) else 0,
		won = won,
		drafts = drafts,
		builds = self.builds,
		nukes = self.nukes,
		edicts = self.edicts,
		nemeses = self.nemeses,
		events = self.events,
		landmarks = self.landmarks,
		eliminated = self.eliminated_at ~= nil,
		eliminated_at = self.eliminated_at,
		mode = if s ~= nil then s.mode else nil,
		map_id = if s ~= nil and s.map ~= nil then s.map.id else nil,
	}
	for k, v in extras do
		r[k] = v
	end
	return r
end

return MatchLog
