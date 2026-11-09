--!strict
-- Stars for a match (shared/Data/Stars; spent in the Arsenal, shared/Data/Arsenal).
--
-- A public match runs on this server: MatchServer follows it (Stars.Tracker) and its results are paid
-- as they are (Rewards.pay). A solo match runs on the player's own device, so its result is the
-- client's word (OP.SOLO_RESULT): it is typed and bounded (Stars.sanitize), can't be longer than the
-- match really lasted on this server's clock (counted from the client's "match_start" report), and
-- never pays more than Stars.solo_cap of that real time. So a made-up report earns no faster than a
-- good player, and nothing at all without the time passing (a match restarted over and over pays nothing).
--
--   Rewards.configure(deps)          { add_stars = fn(player, n, minutes) -> (ok, balance),
--                                      general = fn(player) -> boolean, send = fn(player,
--                                      payload), now = fn() -> s, log? }
-- A Charter holder with a paid cycle (Data/Subscription) gets a stipend for each age the war lived through, a sum of its
-- own that no other line changes (the "general" line).
--   Rewards.solo_started(player, mode)   the client's match_start ("solo0" / "solo1" / "solo2")
--   Rewards.solo_result(player, report)  OP.SOLO_RESULT (yields)
--   Rewards.pay(player, result, mode)    a result this server measured itself (yields)
--   Rewards.release(player)              PlayerRemoving
-- The payload sent to the client (OP.STARS): { lines = { { key, amount } }, total, balance, mode }.
local IS_ROBLOX = typeof(game) == "Instance"
local Stars: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Stars)
	else require("../shared/Data/Stars")
local Subscription: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Subscription)
	else require("../shared/Data/Subscription")

local Rewards = {}

--- Results one solo match may be paid for: its end, and one more for each life a takeover gave it.
Rewards.MAX_SOLO_PAYOUTS = 4
--- Slack on the real time a solo result may claim (the report's trip, the clock's grain), minutes.
Rewards.SLACK_MIN = 0.25

type Solo = { mode: string, paid_at: number, payouts: number }

local deps: { [string]: any } = {}
local solo: { [any]: Solo } = {}

function Rewards.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everyone.
function Rewards.reset()
	table.clear(solo)
end

local function now(): number
	return if deps.now then deps.now() else os.clock()
end

--- `minutes`: how long the match really lasted on this server's clock (what lets Renown from Orders and Medals be
--- claimed: Data/Claims).
local function deliver(player: any, lines: { { any } }, total: number, mode: string, minutes: number): number
	if total <= 0 then
		return 0
	end
	local ok, balance = deps.add_stars(player, total, minutes)
	if not ok then
		return 0
	end
	if deps.send then
		pcall(deps.send, player, { lines = lines, total = total, balance = balance, mode = mode })
	end
	if deps.log then
		deps.log(string.format("[Rewards] %s +%d Stars (%s)", tostring(player.UserId), total, mode))
	end
	return total
end

--- `ages`: the last age the war reached; `mult`: what the mode pays of the formula.
local function with_stipend(player: any, lines: { { any } }, total: number, ages: any, mult: number?): ({ { any } }, number)
	if total > 0 and deps.general and deps.general(player) == true then
		local extra = Subscription.stipend(tonumber(ages) or 1, mult or 1, Stars.QUANTUM)
		if extra > 0 then
			table.insert(lines, { "general", extra })
			total += extra
		end
	end
	return lines, total
end

--- A result this server measured itself (a public match). Returns the Stars paid.
function Rewards.pay(player: any, result: any, mode: string?): number
	local m = mode or "public"
	local p = Stars.payout(result, m)
	local lines0, total0 = p.lines, p.total
	-- (back in a war already paid in part: only what it earned since, as one line)
	local already = tonumber(result.already_paid) or 0
	if already > 0 then
		local rest = math.max(0, total0 - already)
		lines0, total0 = { { "rest", rest } }, rest
	end
	local lines, total = with_stipend(player, lines0, total0, result.ages, Stars.MODE_MULT[m])
	if result.won == true and deps.badge then
		pcall(deps.badge, player, "first_win")
		pcall(deps.badge, player, "public_win")
	end
	local extra = if result.with_friend == true then Stars.warband_bonus(total) else 0
	if extra > 0 then
		table.insert(lines, { "warband", extra })
		total += extra
	end
	return deliver(player, lines, total, m, tonumber(result.minutes) or 0)
end

function Rewards.solo_started(player: any, mode: any)
	if type(mode) ~= "string" or Stars.MODE_MULT[mode] == nil or mode == "public" then
		solo[player] = nil
		return
	end
	solo[player] = { mode = mode, paid_at = now(), payouts = 0 }
end

--- The client's result of the solo match it reported starting. Returns the Stars paid.
function Rewards.solo_result(player: any, report: any): number
	local m = solo[player]
	if m == nil or m.payouts >= Rewards.MAX_SOLO_PAYOUTS then
		return 0
	end
	local t = now()
	local real = math.max(0, (t - m.paid_at) / 60)
	local r = Stars.sanitize(report, real + Rewards.SLACK_MIN)
	if r.won == true and deps.badge then
		pcall(deps.badge, player, "first_win")
		if m.mode == "solo2" then
			pcall(deps.badge, player, "warlord")
		end
	end
	m.payouts += 1
	m.paid_at = t
	if r.left then
		solo[player] = nil -- the match is over for this player
	end
	local p = Stars.payout(r, m.mode)
	-- (the Charter's stipend first, so the cap holds it too: release audit 2026-11-07 found a lean report every few
	-- seconds drawing the stipend 47 times past the cap)
	local lines, total = with_stipend(player, p.lines, p.total, r.ages, Stars.MODE_MULT[m.mode])
	local cap = Stars.solo_cap(real)
	if total > cap then
		-- more than that much real time can pay: every line shrinks alike
		local k = cap / total
		total = 0
		for _, line in lines do
			line[2] = math.floor(line[2] * k / Stars.QUANTUM) * Stars.QUANTUM
			total += line[2]
		end
	end
	return deliver(player, lines, total, m.mode, real)
end

function Rewards.release(player: any)
	solo[player] = nil
end

return Rewards
