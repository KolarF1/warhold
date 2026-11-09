--!strict
-- What the second scoreboard pays: Field Orders, Medals, War Room laurels and Season levels are worked out on the client
-- (Data/Progress, kept in its settings), so the server can't see them earned. Renown is real money in the War College, so
-- each is claimed by id and checked here, against state the server keeps on the player's record (server/Purchases
-- `claims`): never against the client's numbers. The amount always comes from this file, never from the claim.
--
-- What the server can check:
--   known     the id is typed, short and names a real order, medal, mission or level
--   order     an Order must be one of today's or this week's on the server's own UTC day
--   ladder    a medal needs the rung below it; a laurel the one before it and an open mission (paid so far); a Season
--             level the one before it, in the current season
--   once      every id pays once (a day's orders once a day, a week's once a week), kept on the record
--   the day   at most DAILY_CAP Renown a UTC day, of which ONE_OFF_CAP from medals, laurels and levels (they have no
--             deadline, so an old career's backlog pays out over days and today's orders always fit)
--   the clock at most PER_MINUTE Renown a minute of war this UTC day, as the server timed it (server/Rewards)
-- What it cannot check is whether the order, medal or laurel was truly earned. So a tampered client can claim all of
-- them without earning them, for at most: DAILY_CAP a day and only after sitting through that much real time, until the
-- one-offs run out (tests/claims.luau works out every number). It can't buy anything faster than that.
local Orders = require("./Orders")
local Medals = require("./Medals")
local Missions = require("./Missions")
local Season = require("./Season")

local Claims = {}

Claims.DAILY_CAP = 2500
Claims.ONE_OFF_CAP = 750
--- Renown a minute of war on the server's clock lets through.
Claims.PER_MINUTE = 100
--- One message: this many ids, each at most this long, at most one message per GAP_S.
Claims.MAX_IDS = 12
Claims.MAX_ID_LEN = 32
Claims.GAP_S = 2
Claims.LAUREL = 100
Claims.SEASON_LEVEL = 50
Claims.SEASON_FIFTH = 150
--- The daily muster (release 2026-11-07): a seven-day ladder, one rung a UTC day you come. A missed day pauses it, never
--- resets it. It needs no war (it is for coming back), so it stands outside DAILY_CAP and the clock; it can be claimed
--- once a day and its amount comes from here. The seventh rung also brings a free Spoils where they're allowed
--- (server/Purchases.claim_renown).
Claims.MUSTER = { 200, 250, 300, 350, 400, 450, 1000 }
--- The seventh day's free Spoils where Spoils aren't open to the player: this much Renown instead.
Claims.MUSTER_GIFT_RENOWN = 1000
--- Most minutes a day can hold.
local MAX_MINUTES = 1440

local MEDAL_INDEX: { [string]: number } = {}
for i, m in Medals.LIST do
	MEDAL_INDEX[m.key] = i
end
local ORDER_KEYS: { [string]: boolean } = {}
for _, o in Orders.DAILY do
	ORDER_KEYS[o.key] = true
end
for _, o in Orders.WEEKLY do
	ORDER_KEYS[o.key] = true
end

local function tens(x: number): number
	return math.floor(x / 10 + 0.5) * 10
end

--- What an order pays: half its XP.
function Claims.order_amount(o: any): number
	return tens(o.xp * 0.5)
end

--- What a medal pays: half as much again as its XP.
function Claims.medal_amount(m: any): number
	return tens(m.xp * 1.5)
end

--- What reaching Season `level` pays (a fifth level, with its title, pays more).
function Claims.season_amount(level: number): number
	return if level % 5 == 0 then Claims.SEASON_FIFTH else Claims.SEASON_LEVEL
end

function Claims.order_id(o: any): string
	return "o:" .. o.key
end

function Claims.medal_id(m: any): string
	return "m:" .. m.key
end

function Claims.laurel_id(m: any, n: number): string
	return "l:" .. m.key .. ":" .. tostring(n)
end

function Claims.season_id(level: number): string
	return "s:" .. tostring(level)
end

--- The muster's rung `step` (1..7).
function Claims.muster_id(step: number): string
	return "d:" .. tostring(step)
end

--- The rung the muster stands on next, and whether it can be taken on `day` (once a day). Pure in `st`.
function Claims.muster_next(st: any, day: number): (number, boolean)
	local n = if type(st) == "table" and type(st.mu) == "number" then st.mu else 0
	local last = if type(st) == "table" and type(st.mud) == "number" then st.mud else -1
	return n % #Claims.MUSTER + 1, last ~= day
end

local function count(v: any, hi: number): number
	return if type(v) == "number" and v == v then math.clamp(math.floor(v), 0, hi) else 0
end

--- A saved `claims` section made safe (a record from before this field: an empty one). Everything is bounded by the
--- catalogues: this can't grow.
function Claims.clean(v: any): { [string]: any }
	local s = if type(v) == "table" then v else {}
	local function keys(t: any): { [string]: boolean }
		local out: { [string]: boolean } = {}
		if type(t) == "table" then
			for k, on in t do
				if on == true and ORDER_KEYS[k] then
					out[k] = true
				end
			end
		end
		return out
	end
	return {
		d = count(s.d, 1e9),
		w = count(s.w, 1e9),
		paid = count(s.paid, Claims.DAILY_CAP),
		oneoff = count(s.oneoff, Claims.ONE_OFF_CAP),
		-- (not whole minutes: every write passes through here, and a short war must not be lost)
		min = if type(s.min) == "number" and s.min == s.min then math.clamp(s.min, 0, MAX_MINUTES) else 0,
		o = keys(s.o),
		ow = keys(s.ow),
		md = Medals.encode(Medals.earned(s.md)),
		ml = Missions.encode(Missions.best(s.ml)),
		s = count(s.s, 1e9),
		sl = math.max(count(s.sl, Season.LEVELS), 1),
		-- the muster: rungs taken in all, and the UTC day of the last
		mu = count(s.mu, 1e9),
		mud = if type(s.mud) == "number" and s.mud == s.mud then math.floor(s.mud) else -1,
	}
end

--- `st` as of `day`: a new day clears the day's counts and orders, a new week the week's, a new season its level.
local function roll(st: { [string]: any }, day: number)
	if st.d ~= day then
		st.d, st.paid, st.oneoff, st.min = day, 0, 0, 0
		st.o = {}
	end
	if st.w ~= day // 7 then
		st.w = day // 7
		st.ow = {}
	end
	local number = Season.current(day).number
	if st.s ~= number then
		st.s, st.sl = number, 1
	end
end
Claims.roll = roll

--- A war the server timed: `minutes` more of it today.
function Claims.add_minutes(st: { [string]: any }, minutes: any, day: number)
	roll(st, day)
	if type(minutes) == "number" and minutes == minutes and minutes > 0 then
		st.min = math.min(st.min + minutes, MAX_MINUTES)
	end
end

local function find_order(key: string, day: number): (any, boolean)
	for _, o in Orders.daily(day) do
		if o.key == key then
			return o, false
		end
	end
	for _, o in Orders.weekly(day) do
		if o.key == key then
			return o, true
		end
	end
	return nil, false
end

--- What claim `id` would do: its amount and whether it comes from the one-offs' share; or nil and why not.
--- The second answer is "claimed", "unknown", "not today" or "too soon". Doesn't look at the caps.
local function look(st: { [string]: any }, id: any, day: number): (number?, any, any)
	if type(id) ~= "string" or #id > Claims.MAX_ID_LEN then
		return nil, "unknown"
	end
	local kind: any, rest: any = string.match(id, "^(%a):(.+)$")
	if kind == "o" then
		if not ORDER_KEYS[rest] then
			return nil, "unknown"
		end
		local o, weekly = find_order(rest, day)
		if o == nil then
			return nil, "not today"
		end
		if (if weekly then st.ow else st.o)[rest] then
			return nil, "claimed"
		end
		return Claims.order_amount(o), false, function()
			(if weekly then st.ow else st.o)[rest] = true
		end
	elseif kind == "m" then
		local i = MEDAL_INDEX[rest]
		if i == nil then
			return nil, "unknown"
		end
		local paid = Medals.earned(st.md)
		if paid[i] then
			return nil, "claimed"
		end
		local m = Medals.LIST[i]
		local below = Medals.LIST[i - 1]
		if below ~= nil and below.stat == m.stat and not paid[i - 1] then
			return nil, "too soon"
		end
		return Claims.medal_amount(m), true, function()
			paid[i] = true
			st.md = Medals.encode(paid)
		end
	elseif kind == "l" then
		local key, n = string.match(rest, "^(.+):(%d)$")
		local i = if key ~= nil then Missions.INDEX[key] else nil
		local want = tonumber(n)
		if i == nil or want == nil or want < 1 or want > 3 then
			return nil, "unknown"
		end
		local best = Missions.best(st.ml)
		if best[i] >= want then
			return nil, "claimed"
		end
		if best[i] ~= want - 1 or not Missions.unlocked(i, best) then
			return nil, "too soon"
		end
		return Claims.LAUREL, true, function()
			best[i] = want
			st.ml = Missions.encode(best)
		end
	elseif kind == "d" then
		local step = tonumber(rest)
		local want, open = Claims.muster_next(st, day)
		if step == nil or step ~= math.floor(step) or step < 1 or step > #Claims.MUSTER then
			return nil, "unknown"
		end
		if not open then
			return nil, "claimed"
		end
		if step ~= want then
			return nil, "too soon"
		end
		return Claims.MUSTER[step], "muster", function()
			st.mu += 1
			st.mud = day
		end
	elseif kind == "s" then
		local level = tonumber(rest)
		if level == nil or level ~= math.floor(level) or level < 2 or level > Season.LEVELS then
			return nil, "unknown"
		end
		if level <= st.sl then
			return nil, "claimed"
		end
		if level ~= st.sl + 1 then
			return nil, "too soon"
		end
		-- (not from the one-offs' share: a season ends, so its levels must drain within it like the orders do; release
		-- audit 2026-11-07 found a season's last levels lost to the share at the reset)
		return Claims.season_amount(level), false, function()
			st.sl = level
		end
	end
	return nil, "unknown"
end

--- Claim `id` on state `st` (rolled to `day`): the Renown it pays, or nil and why not ("claimed", "unknown", "not today",
--- "too soon", "cap": the day's share is spent, "clock": not enough war timed today).
function Claims.apply(st: { [string]: any }, id: any, day: number): (number?, string?)
	roll(st, day)
	local amount, one_off, take = look(st, id, day)
	if amount == nil then
		return nil, one_off
	end
	if one_off == "muster" then
		-- (coming back is the point: no cap, no clock; once a day by the rung's own day check)
		take()
		return amount, nil
	end
	if st.paid + amount > Claims.DAILY_CAP or (one_off and st.oneoff + amount > Claims.ONE_OFF_CAP) then
		return nil, "cap"
	end
	if st.paid + amount > st.min * Claims.PER_MINUTE then
		return nil, "clock"
	end
	take()
	st.paid += amount
	if one_off then
		st.oneoff += amount
	end
	return amount, nil
end

--- True when `id` has been paid, as `st` (the inventory's copy, or nil before it loads) tells it on `day`.
function Claims.is_paid(st: any, id: string, day: number): boolean
	if type(st) ~= "table" then
		return false
	end
	local copy = Claims.clean(st)
	roll(copy, day)
	local _, why = look(copy, id, day)
	return why == "claimed"
end

--- What a career has earned that hasn't been paid, oldest debts last: orders first, because they run out with the day.
--- `career`: Progress.clean's answer; `st`: the inventory's copy of the record's claims.
function Claims.pending(career: { [string]: any }, st: any, day: number): { string }
	local copy = Claims.clean(st)
	roll(copy, day)
	local out: { string } = {}
	local function want(id: string)
		local amount = look(copy, id, day)
		-- (one that's "too soon" now comes up once what's before it has been paid: asked for in the same order)
		local _, why = look(copy, id, day)
		if amount ~= nil or why == "too soon" then
			table.insert(out, id)
		end
	end
	-- the daily muster first: it is for coming back, and needs no war
	local step, open = Claims.muster_next(copy, day)
	if open then
		table.insert(out, Claims.muster_id(step))
	end
	local o = Orders.current(career.o, day)
	for i, order in Orders.daily(day) do
		if ({ o.a, o.b, o.c })[i] >= order.goal then
			want(Claims.order_id(order))
		end
	end
	for i, order in Orders.weekly(day) do
		if ({ o.x, o.y, o.z })[i] >= order.goal then
			want(Claims.order_id(order))
		end
	end
	local best = Missions.best(career.missions)
	for i, m in Missions.LIST do
		for n = 1, best[i] do
			want(Claims.laurel_id(m, n))
		end
	end
	for i, on in Medals.earned(career.medals) do
		if on then
			want(Claims.medal_id(Medals.LIST[i]))
		end
	end
	if career.season == copy.s then
		for level = 2, Season.level(career.season_xp or 0).level do
			want(Claims.season_id(level))
		end
	end
	return out
end

--- The Renown one match's result (Progress.after_match) has earned: { orders, medals, laurels, season, total }.
function Claims.of_result(r: { [string]: any }): { [string]: number }
	local out = { orders = 0, medals = 0, laurels = 0, season = 0, total = 0 }
	for _, o in r.orders or {} do
		out.orders += Claims.order_amount(o)
	end
	for _, m in r.medals or {} do
		out.medals += Claims.medal_amount(m)
	end
	out.laurels = (r.mission_stars_new or 0) * Claims.LAUREL
	if r.season_up == true and r.season_from ~= nil then
		for level = r.season_from + 1, r.season_level or 0 do
			out.season += Claims.season_amount(level)
		end
	end
	out.total = out.orders + out.medals + out.laurels + out.season
	return out
end

return Claims
