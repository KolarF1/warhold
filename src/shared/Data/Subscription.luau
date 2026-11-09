--!strict
-- The Sovereign's Charter: a monthly Roblox subscription, paid in Robux (Creator Dashboard -> Monetization ->
-- Subscriptions; Roblox renews and bills it, and players cancel it in Roblox's own settings). It is off sale until `ID` is
-- set. What a holder gets, and the same for every holder on every device (server/General, server/Purchases.general_perks):
--   * DAILY_RENOWN Renown for every day a paid cycle covers: a fixed sum, nothing rolled, so the Charter is not a paid
--     random item anywhere. A day they don't play is not lost: the next join pays it, even after they cancel.
--   * A stipend of AGE_STIPEND Renown for each age a war lived through (server/Rewards: the "general" line). A flat sum by
--     how far the war went, in the same share a mode pays of everything else; no percentage of anything.
--   * The Charter's Pattern (SKINS; Data/Cosmetics.general_skins), theirs to keep. One Pattern: nothing promises more.
-- Nothing is paid on Roblox's "subscribed" alone: while a renewal is still processing, that stays true before the money
-- has arrived. Only a cycle whose PaymentStatus is Paid counts (`cycles`, from GetUserSubscriptionPaymentHistoryAsync, which
-- reaches back 12 months), so a refunded cycle pays nothing and an unconfirmed renewal pays once it is confirmed.
-- `general_day` in a save means the last day paid; a save from when it meant something else only ever gets later days.
--
-- `ID` is the subscription's id ("EXP-..."; "" = not created yet: nothing offers it), `STAGING` the same subscription in
-- Rofront Staging. Create it with product type Durable; see docs/RELEASE_CHECKLIST.md.
local IS_ROBLOX = typeof(game) == "Instance"
local Staging: any = if IS_ROBLOX then require((script :: any).Parent.Staging) else (require :: any)("./Staging")

local Subscription = {}

Subscription.ID = "EXP-2484645269344485934"
Subscription.STAGING = ""
Subscription.NAME = "Sovereign's Charter"
--- The price to set on the dashboard (Robux a month). The interface never prints this: it shows Roblox's, or nothing.
Subscription.ROBUX = 349
Subscription.DAILY_RENOWN = 3000
Subscription.AGE_STIPEND = 130
--- What the Charter's sheet says of the stipend (server/Rewards pays it: tests/general.luau keeps the number the same).
Subscription.STIPEND_LINE = "130 Renown for each age your war lives through"
--- The Charter's Pattern.
Subscription.SKINS = {
	{ month = "2026-10", skin = "gen_chevrons" },
}

--- The subscription's id in this experience ("" where there is none).
function Subscription.id(): string
	return if Staging.here() then Subscription.STAGING else Subscription.ID
end

--- The UTC day number of unix time `t`.
function Subscription.day(t: number): number
	return math.floor(t / 86400)
end

--- The Charter's Pattern on offer at unix time `t`.
function Subscription.skin_for(t: number): string?
	local month = os.date("!%Y-%m", math.floor(t)) :: string
	local skin = nil
	for _, s in Subscription.SKINS do
		if s.month <= month then
			skin = s.skin
		end
	end
	return skin or (if #Subscription.SKINS > 0 then Subscription.SKINS[1].skin else nil)
end

--- What a war pays a holder on top: AGE_STIPEND for each of its `ages`, times the share `mult` its mode pays, in whole QUANTUMs.
function Subscription.stipend(ages: number, mult: number, quantum: number): number
	local q = math.max(quantum, 1)
	local n = math.clamp(math.floor(ages), 1, 4)
	return math.floor(Subscription.AGE_STIPEND * n * math.max(mult, 0) / q) * q
end

--- A payment history (GetUserSubscriptionPaymentHistoryAsync's rows) as the paid cycles' UTC days: { { from, to } }, oldest
--- first. `paid`: the status that counts (Enum.SubscriptionPaymentStatus.Paid). A row that can't be read counts as unpaid.
function Subscription.cycles(history: any, paid: any): { { from: number, to: number } }
	local out = {}
	if type(history) ~= "table" then
		return out
	end
	for _, row in history do
		if type(row) == "table" and row.PaymentStatus == paid then
			local a, b = row.CycleStartTime, row.CycleEndTime
			local s = if a ~= nil then tonumber(a.UnixTimestamp) else nil
			local e = if b ~= nil then tonumber(b.UnixTimestamp) else nil
			if s ~= nil and e ~= nil and e > s then
				-- (a cycle ending at midnight doesn't reach into the day it ends on)
				table.insert(out, { from = Subscription.day(s), to = Subscription.day(e - 1) })
			end
		end
	end
	table.sort(out, function(x, y)
		return x.from < y.from
	end)
	return out
end

--- Does a paid cycle cover UTC day `day`?
function Subscription.paid_on(cycles: { any }, day: number): boolean
	for _, c in cycles do
		if day >= c.from and day <= c.to then
			return true
		end
	end
	return false
end

--- The days still owed: every day up to `today` inside a paid cycle and after `last_day` (nil: none paid yet). Returns
--- (how many, the last of them, or nil when none). Overlapping cycles count a day once.
function Subscription.days_owed(cycles: { any }, last_day: number?, today: number): (number, number?)
	local n, last = 0, nil
	local done = last_day
	for _, c in cycles do
		local from = if done ~= nil then math.max(c.from, done + 1) else c.from
		local to = math.min(c.to, today)
		if to >= from then
			n += to - from + 1
			last = to
			done = to
		end
	end
	return n, last
end

return Subscription
