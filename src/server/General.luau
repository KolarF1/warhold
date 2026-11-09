--!strict
-- The Sovereign's Charter (Data/Subscription): who on this server holds it, and paying them. Two questions go to Roblox:
-- are they subscribed (deps.status, when they join and on Players.UserSubscriptionStatusChanged), and which cycles have
-- really been paid (deps.history). Money follows the second. A holder's days are settled on joining, on subscribing, and
-- at the first tick of each new UTC day; a day whose payment isn't confirmed yet (a renewal being processed, Roblox not
-- answering) is simply asked about again at the next tick, and paid then. A player who has cancelled is still settled
-- once on joining, so days they paid for and never came back for aren't lost. If Roblox doesn't answer the status question
-- at join, the player's standing is unknown, not "no": each tick asks again until it answers.
-- The client hears OP.GENERAL: { on, given? }.
--
--   General.configure(deps)   { status = fn(player) -> boolean? (nil: Roblox didn't answer),
--                               history = fn(player) -> Subscription.cycles' list (nil or an error: Roblox didn't answer),
--                               perks = fn(player, cycles, day, skin) -> given? (nil: not stored),
--                               send = fn(player, state), now = fn() -> unix s,
--                               subscribed = fn(player)? (they just subscribed), log? }
--   General.joined(player)    PlayerAdded (yields)
--   General.changed(player)   UserSubscriptionStatusChanged for this subscription (yields)
--   General.active(player) -> boolean   subscribed, and today is inside a paid cycle: the match bonus goes by this
--   General.state(player) -> { on }     for a client that says HELLO
--   General.tick()            about once a minute: settles holders, asks again about anyone Roblox didn't answer for (yields)
--   General.release(player)   PlayerRemoving
local IS_ROBLOX = typeof(game) == "Instance"
local Subscription: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Subscription)
	else require("../shared/Data/Subscription")

local General = {}

--- Asking Roblox whether a player is subscribed: attempts, and the wait between them (s).
General.STATUS_ATTEMPTS = 3
General.STATUS_WAIT_S = 2

--- on: subscribed; paid: a paid cycle covers `day`; day: the UTC day settled this session (nil: not yet);
--- unknown: Roblox hasn't answered yet whether they are subscribed (the tick asks again; `on` is false until it does)
type Entry = { on: boolean, paid: boolean, day: number?, unknown: boolean? }

local deps: { [string]: any } = {}
local entries: { [any]: Entry } = {}

function General.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everyone.
function General.reset()
	table.clear(entries)
end

local function now(): number
	return if deps.now then deps.now() else os.time()
end

local function send(player: any, state: any)
	if deps.send then
		pcall(deps.send, player, state)
	end
end

--- Subscribed? Asked `attempts` times (default STATUS_ATTEMPTS); nil when Roblox never answered.
local function status(player: any, attempts: number?): boolean?
	local tries = attempts or General.STATUS_ATTEMPTS
	for i = 1, tries do
		local ok, on = pcall(deps.status, player)
		if ok and type(on) == "boolean" then
			return on
		end
		if i < tries and IS_ROBLOX then
			task.wait(General.STATUS_WAIT_S)
		end
	end
	if deps.log then
		deps.log("[General] no subscription status for " .. tostring(player.UserId))
	end
	return nil
end

--- Pay what the paid cycles owe. A day counts as settled only when it is confirmed paid (or they no longer hold the
--- Charter, so nothing more is coming): anything else is asked again at the next tick.
local function settle(player: any, e: Entry)
	local t = now()
	local day = Subscription.day(t)
	if e.day == day then
		return
	end
	local got, cycles = pcall(deps.history, player)
	if not got or type(cycles) ~= "table" then
		if deps.log then
			deps.log("[General] no payment history for " .. tostring(player.UserId))
		end
		return
	end
	e.paid = Subscription.paid_on(cycles, day)
	local ok, given = pcall(deps.perks, player, cycles, day, Subscription.skin_for(t))
	if not ok or given == nil then
		return -- (the store failed: nothing was marked paid, so the next tick pays it)
	end
	if e.paid or not e.on then
		e.day = day
	end
	if next(given) ~= nil then
		send(player, { on = if e.unknown then nil else e.on, given = given })
	end
end

function General.joined(player: any)
	if Subscription.id() == "" or deps.status == nil then
		return
	end
	local on = status(player)
	if entries[player] ~= nil or (IS_ROBLOX and player.Parent == nil) then
		return -- (changed() got there first, or they left while Roblox answered)
	end
	local e: Entry = { on = on == true, paid = false, unknown = if on == nil then true else nil }
	entries[player] = e
	-- (no answer: say nothing yet, the client hasn't been told they don't hold it)
	if on ~= nil then
		send(player, { on = e.on })
	end
	settle(player, e)
end

function General.changed(player: any)
	if Subscription.id() == "" or deps.status == nil then
		return
	end
	local on = status(player)
	if on == nil then
		return
	end
	local e = entries[player]
	if e == nil then
		e = { on = false, paid = false }
		entries[player] = e
	end
	e.unknown = nil
	if e.on ~= on then
		e.on = on
		e.day = nil -- (a new subscription's first cycle is worth asking about at once)
		if on and deps.subscribed then
			pcall(deps.subscribed, player)
		end
		if deps.log then
			deps.log(
				string.format(
					"[General] %s %s",
					tostring(player.UserId),
					if on then "subscribed" else "is no longer subscribed"
				)
			)
		end
		send(player, { on = on })
	end
	settle(player, e)
end

function General.active(player: any): boolean
	local e = entries[player]
	return e ~= nil and e.on and e.paid
end

function General.state(player: any): any
	local e = entries[player]
	-- (nil while Roblox hasn't answered: nobody has said they don't hold it)
	return { on = if e ~= nil and e.unknown then nil else e ~= nil and e.on }
end

--- A player whose status Roblox didn't give: one question, so a slow answer doesn't hold the others up for long.
local function ask_again(player: any, e: Entry)
	local on = status(player, 1)
	if on == nil or entries[player] ~= e or not e.unknown then
		return -- (still no answer; or they left, or changed() got there first, while Roblox answered)
	end
	e.unknown = nil
	e.on = on
	send(player, { on = on })
	if on then
		e.day = nil -- (joining settled today as a non-holder: as a holder today may still be unconfirmed)
		settle(player, e)
	end
end

function General.tick()
	for player, e in entries do
		if e.unknown then
			ask_again(player, e)
		elseif e.on then
			settle(player, e)
		end
	end
end

function General.release(player: any)
	entries[player] = nil
end

return General
