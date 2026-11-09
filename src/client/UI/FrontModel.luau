--!nonstrict
-- Your front's rows (2026-11-02, the command dial): what the war means for you now, read from the match's state, never
-- from the news. Three tabs:
--   threats  a warhead or a raid falling on your land, a nation marching on you, a neighbour massing on your border;
--   marches  your own attacks (troops left of the most seen in them), landings at sea (how far along), land you claim;
--   talks    a pact offered to you (Seal / Refuse in the row), a pact near its end (Keep it), an offer of yours unanswered.
-- Pure: FrontModel.collect(input) -> { threats = {...}, marches = {...}, talks = {...} }, each most urgent first, and
-- FrontModel.auto_tab(...) picks a tab to open by itself. The strategy frame's outliner (UI/Outliner) draws YOUR ATTACKS
-- and THREATS from them.
--
-- An item: { key, tab, kind, urgency, owner, line, sub, tone ("red" | "amber" | "green" | "muted"), focus_tile,
-- progress (0..1, or nil), aid (an attack of yours), actions ({ "accept", "refuse" } | { "keep" } | { "recall" } | nil) }.

local FrontModel = {}

FrontModel.TABS = { "threats", "marches", "talks" }
FrontModel.TAB_TITLE = { threats = "THREATS", marches = "MARCHES", talks = "TALKS" }
--- A neighbour with this many times your army, not already at war with you, is massing on your border.
FrontModel.MASSING_X = 1.5
--- At most this many massing neighbours are listed (the largest).
FrontModel.MASSING_MAX = 3
--- How urgent each kind of item is (the larger first); an attack on you and massing add their odds on top.
FrontModel.URGENCY = {
	nuke = 300,
	attack_in = 200,
	request_in = 150,
	renewal = 120,
	massing = 100,
	march = 60,
	landing = 55,
	request_out = 20,
	claim = 10,
}
--- A tab opens by itself only for a new item this urgent at least (a claim never pulls you away), and never this soon
--- after the player picked a tab.
FrontModel.AUTO_MIN = 100
FrontModel.MANUAL_HOLD_MS = 4000

--- Troops as the rows say them (the HUD's own format, passed in so this stays pure).
local function fmt(input: any, v: number): string
	return if input.fmt_troops ~= nil then input.fmt_troops(v) else tostring(math.floor(v + 0.5))
end

local function time_text(input: any, s: number): string
	return if input.fmt_time ~= nil then input.fmt_time(math.max(0, math.ceil(s))) else tostring(math.ceil(s))
end

--- The rows for the local player. `input`:
---   state (GameState-like), me, my_troops, tick (the render tick), tick_rate,
---   neighbours ({ owner ids }: who borders you by land), seen ({ [aid] = the most troops seen }; updated here),
---   request_ticks (how long an offer stands), title_of_nuke ((kind) -> string), fmt_troops, fmt_time.
function FrontModel.collect(input: any): { [string]: { any } }
	local s = input.state
	local me = input.me or 0
	local out = { threats = {}, marches = {}, talks = {} }
	if s == nil or me == 0 then
		return out
	end
	local U = FrontModel.URGENCY
	local rate = input.tick_rate or 10
	local now = input.tick or s.tick or 0
	local mine = math.max(input.my_troops or 0, 1)
	local seen = input.seen or {}
	local function name(id: number): string
		return if id ~= 0 then s:owner_name(id) else "free land"
	end
	local function add(tab: string, it: any)
		it.tab = tab
		table.insert(out[tab], it)
	end
	-- warheads and raids falling on your land
	for uid, n in s.nukes or {} do
		local to = tonumber(n.to_tile) or -1
		if to >= 0 and n.owner ~= me and s:tile_owner(to) == me then
			local left = ((tonumber(n.launch_tick) or 0) + (tonumber(n.flight_ticks) or 0) - now) / rate
			local title = if input.title_of_nuke ~= nil then input.title_of_nuke(n.kind) else "Warhead"
			add("threats", {
				key = "nuke:" .. tostring(uid),
				kind = "nuke",
				urgency = U.nuke + math.max(0, 30 - left),
				owner = n.owner,
				line = string.format("%s from %s", title, name(n.owner)),
				sub = if left > 0 then "Falls on you in " .. time_text(input, left) else "Falling now",
				tone = "red",
				focus_tile = to,
			})
		end
	end
	-- attacks: on you, and yours
	local at_war = {}
	for aid, a in s.attacks or {} do
		local troops = tonumber(a.troops) or 0
		seen[aid] = math.max(seen[aid] or 0, troops)
		if a.target == me and a.attacker ~= me then
			at_war[a.attacker] = true
			local odds = troops / mine
			add("threats", {
				key = "atk:" .. tostring(aid),
				kind = "attack_in",
				urgency = U.attack_in + math.min(odds, 9),
				owner = a.attacker,
				line = string.format("%s is inside your border", name(a.attacker)),
				sub = string.format("%s troops%s", fmt(input, troops), if odds > 1 then " · more than you hold" else " · your army can stop it"),
				tone = if odds > 1 then "red" else "amber",
				focus_tile = a.anchor_tile,
			})
		elseif a.attacker == me then
			if a.target ~= 0 then
				at_war[a.target] = true
			end
			local most = math.max(seen[aid] or troops, 1)
			local claim = a.target == 0
			add("marches", {
				key = "mar:" .. tostring(aid),
				kind = if claim then "claim" else "march",
				urgency = if claim then U.claim else U.march + math.min(troops / mine, 9),
				owner = a.target,
				line = if claim then "Claiming free land" else string.format("Marching on %s", name(a.target)),
				sub = if a.retreating
					then string.format("%s troops · coming home", fmt(input, troops))
					else string.format("%s troops · %d%% of them left", fmt(input, troops), math.floor(troops / most * 100 + 0.5)),
				tone = if a.retreating then "muted" elseif claim then "green" else "amber",
				focus_tile = a.anchor_tile,
				progress = math.clamp(troops / most, 0, 1),
				aid = aid,
				actions = if a.retreating or claim then nil else { "recall" },
			})
		end
	end
	-- (attacks that ended: their high marks go)
	for aid in seen do
		if s.attacks == nil or s.attacks[aid] == nil then
			seen[aid] = nil
		end
	end
	-- landings at sea
	for uid, u in s.units or {} do
		if u.owner == me and u.kind == (input.transport_kind or 0) then
			local path = u.path or {}
			local n = #path
			local dest = if n > 0 then path[n] else -1
			local target = if dest >= 0 then s:tile_owner(dest) else 0
			local done = 0.0
			if n >= 2 then
				local tiles = math.max(0, (now - (tonumber(u.start_tick) or now)) * 100 / math.max(tonumber(u.ticks_per_tile_x100) or 100, 1))
				done = math.clamp(tiles / (n - 1), 0, 1)
			end
			add("marches", {
				key = "boat:" .. tostring(uid),
				kind = "landing",
				urgency = U.landing,
				owner = target,
				line = if target ~= 0 and target ~= me then string.format("Landing bound for %s", name(target)) else "Landing on free land",
				sub = string.format("%s troops · %d%% of the way", fmt(input, tonumber(u.troops) or 0), math.floor(done * 100 + 0.5)),
				tone = "amber",
				focus_tile = dest,
				progress = done,
			})
		end
	end
	-- neighbours massing on your border (not already at war with you, not your pact partners)
	local massing = {}
	for _, id in input.neighbours or {} do
		local o = s:get_owner(id)
		if o ~= nil and o.alive ~= false and id ~= me and not at_war[id] and not s:are_allies(me, id) then
			local t = tonumber(o.troops) or 0
			if t >= FrontModel.MASSING_X * mine then
				table.insert(massing, { id = id, troops = t })
			end
		end
	end
	table.sort(massing, function(a, b)
		if a.troops ~= b.troops then
			return a.troops > b.troops
		end
		return a.id < b.id
	end)
	for i = 1, math.min(#massing, FrontModel.MASSING_MAX) do
		local m = massing[i]
		add("threats", {
			key = "mass:" .. tostring(m.id),
			kind = "massing",
			urgency = U.massing + math.min(m.troops / mine, 9),
			owner = m.id,
			line = string.format("%s is massing", name(m.id)),
			sub = string.format("%s troops on your border, %.1fx yours", fmt(input, m.troops), m.troops / mine),
			tone = "amber",
			focus_tile = if s.label_tile ~= nil then s:label_tile(m.id) else -1,
		})
	end
	-- pacts
	local span = input.request_ticks or 200
	for key, made in s.requests or {} do
		local from, to = key // 1024, key % 1024
		if to == me and from ~= me then
			local left = ((tonumber(made) or now) + span - now) / rate
			add("talks", {
				key = "req:" .. tostring(from),
				kind = "request_in",
				urgency = U.request_in + math.max(0, 20 - left),
				owner = from,
				line = string.format("%s offers a pact", name(from)),
				sub = "Answer within " .. time_text(input, left),
				tone = "amber",
				focus_tile = if s.label_tile ~= nil then s:label_tile(from) else -1,
				actions = { "accept", "refuse" },
			})
		elseif from == me and to ~= me then
			add("talks", {
				key = "out:" .. tostring(to),
				kind = "request_out",
				urgency = U.request_out,
				owner = to,
				line = string.format("Your pact offer to %s", name(to)),
				sub = "No answer yet",
				tone = "muted",
				focus_tile = if s.label_tile ~= nil then s:label_tile(to) else -1,
			})
		end
	end
	if s.allies_of ~= nil then
		for _, other in s:allies_of(me) do
			local ai = s:alliance_info(me, other)
			if ai ~= nil and ai.in_window and ai.expires_at >= 0 then
				local left = ai.ticks_left / rate
				add("talks", {
					key = "renew:" .. tostring(other),
					kind = "renewal",
					urgency = U.renewal + math.max(0, 30 - left),
					owner = other,
					line = string.format("Pact with %s ends in %s", name(other), time_text(input, left)),
					sub = if ai.me_asked then "You asked to keep it" elseif ai.other_asked then "They would keep it" else "Keep it, or let it end",
					tone = if ai.other_asked then "green" else "amber",
					focus_tile = if s.label_tile ~= nil then s:label_tile(other) else -1,
					actions = if ai.can_extend then { "keep" } else nil,
				})
			end
		end
	end
	for _, tab in FrontModel.TABS do
		FrontModel.sort(out[tab])
	end
	return out
end

--- Most urgent first; ties by key, so the order never flickers. Pure (sorts in place).
function FrontModel.sort(list: { any }): { any }
	table.sort(list, function(a, b)
		if a.urgency ~= b.urgency then
			return a.urgency > b.urgency
		end
		return a.key < b.key
	end)
	return list
end

--- The tab to show: `current`, unless a new item (its key not in `seen`) at least AUTO_MIN urgent arrived that is more
--- urgent than the current tab's first, and the player has not picked a tab in the last MANUAL_HOLD_MS. Returns the tab
--- and the item that moved it (nil when it stays). Pure.
function FrontModel.auto_tab(current: string, lists: { [string]: { any } }, seen: { [string]: boolean }, now_ms: number, manual_ms: number?): (string, any)
	local best = nil
	for _, tab in FrontModel.TABS do
		for _, it in lists[tab] or {} do
			if not seen[it.key] and it.urgency >= FrontModel.AUTO_MIN and (best == nil or it.urgency > best.urgency) then
				best = it
			end
		end
	end
	if best == nil or best.tab == current then
		return current, nil
	end
	if manual_ms ~= nil and now_ms - manual_ms < FrontModel.MANUAL_HOLD_MS then
		return current, nil
	end
	local top = (lists[current] or {})[1]
	if top ~= nil and top.urgency >= best.urgency then
		return current, nil
	end
	return best.tab, best
end

--- The one line a phone's badge shows: the most urgent item of all, and how many there are. Pure.
function FrontModel.headline(lists: { [string]: { any } }): (any, number)
	local best, n = nil, 0
	for _, tab in FrontModel.TABS do
		for _, it in lists[tab] or {} do
			n += 1
			if best == nil or it.urgency > best.urgency then
				best = it
			end
		end
	end
	return best, n
end

return FrontModel
