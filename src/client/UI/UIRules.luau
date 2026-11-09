-- Port of scripts/ui/ui_rules.gd
-- Client-side game knowledge for the interface: build/nuke catalogue, costs (via Rules), what a
-- click on a tile would do, radial-menu contents and placement checks. These are hints only; the
-- Sim validates every intent for real.
-- (The GDScript's unused private helpers _site_ok / _nearest_own / _neighbours4 are left out.)

local UICtx = require("./UICtx") :: any
local Defs = UICtx.core("Defs")

local _Rules: any = nil
local function Rules(): any
	if _Rules == nil then
		_Rules = UICtx.core("Rules")
	end
	return _Rules
end
local _Theme: any = nil
local function T(): any
	if _Theme == nil then
		_Theme = UICtx.mod("UITheme")
	end
	return _Theme
end

local _Arsenal: any = nil
local function Arsenal(): any
	if _Arsenal == nil then
		_Arsenal = UICtx.data("Arsenal")
	end
	return _Arsenal
end

local UIRules = {}
UIRules.__index = UIRules

--- Warhold's order: the order the ages open them (Data/Eras.BUILD_OPENS).
UIRules.BUILD_KINDS = { "city", "port", "factory", "defense", "warship", "sam", "silo" }
UIRules.NUKE_KINDS = { "atom", "hydrogen", "mirv" }
--- Hotkeys 1..9, 0 in this order.
UIRules.ACTIONS = { "city", "port", "factory", "defense", "warship", "sam", "silo", "atom", "hydrogen", "mirv" }
UIRules.HOTKEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
--- The Arsenal's kinds (Data/Arsenal: unlocked with Stars or Robux), in the order of its tray:
--- structures, munitions launched like a nuke (the last two from their own structure: strikes), and
--- the Reinforcements call. A locked one is offered in the Arsenal instead of doing anything.
UIRules.ARSENAL_BUILD = { "artillery", "airfield", "railgun" }
UIRules.ARSENAL_NUKES = { "mega", "scatter", "airstrike", "slug" }
UIRules.ARSENAL = { "artillery", "airfield", "railgun", "mega", "scatter", "airstrike", "slug", "reinforce" }

UIRules.TITLES = {
	city = "City",
	port = "Harbor",
	factory = "Foundry",
	defense = "Bastion",
	sam = "Flak Battery",
	silo = "Launch Site",
	warship = "Frigate",
	atom = "Warhead",
	hydrogen = "Great Warhead",
	mirv = "Cluster Warhead",
	artillery = "Long Guns",
	airfield = "Aerodrome",
	railgun = "Lance Cannon",
	mega = "Sunbreaker",
	scatter = "Shatter Line",
	airstrike = "Sky Raid",
	slug = "Lance Shot",
	reinforce = "Harvest Levy",
	callarms = "Call to Arms",
	farm = "Farm",
	market = "Market",
	barracks = "Barracks",
	fort = "Fort",
}
-- (a start date's own names follow the match: Data/PeriodTech)
UICtx.data("PeriodTech").track(UIRules.TITLES)
UIRules.SHORT = {
	city = "Fort",
	port = "Harbor",
	factory = "Foundry",
	defense = "Bastion",
	sam = "Flak",
	silo = "Site",
	warship = "Frigate",
	atom = "Warhead",
	hydrogen = "Heavy",
	mirv = "Cluster",
	artillery = "Guns",
	airfield = "Aero",
	railgun = "Lance",
	mega = "Breaker",
	scatter = "Shatter",
	airstrike = "Sky Raid",
	slug = "Shot",
	reinforce = "Levy",
	callarms = "Call",
	farm = "Farm",
	market = "Market",
	barracks = "Barracks",
	fort = "Fort",
}
UICtx.data("PeriodTech").track(UIRules.SHORT, nil, "short")
UIRules.BLURBS = {
	city = "A seat of power. Holds {city} more troops and ties into your roads.",
	port = "Built on the coast. Its trade ships bring gold, and it launches your Frigates.",
	factory = "Where roads meet. Trucks earn gold at each stop on their way.",
	defense = "Attackers pay {def_mag}x the troops and {def_cost}x the time for land within {def_r} tiles.",
	sam = "Knocks warheads out of the sky within {sam_r} tiles. Cluster Shards get through.",
	silo = "You need one before any warhead can fly.",
	warship = "Your ship of war. It goes where you point, hunts what comes by sea and takes trade for you. Your Harbors repair it.",
	atom = "A small blast. Clears troops and buildings, and poisons the ground.",
	hydrogen = "A huge blast. Nothing inside it survives.",
	mirv = "Opens in flight over one nation: up to {mirv_n} shards, spread across its land.",
	artillery = "Quiet until war comes. Shells any nation at war with you within {art_r} tiles, and breaks up forces marching on you.",
	airfield = "Its Sky Raids reach {air_r} tiles. Crews need {air_s} s between raids.",
	railgun = "Fires up to {rail_r} tiles, through every building near the end of its line. Needs {rail_s} s between shots.",
	mega = "Burns buildings, ships and armies across {mega_r} tiles. Takes no land and leaves it clean.",
	scatter = "A small burst, then {scat_hi} shards in a straight line across your aim.",
	airstrike = "Grounds Flak and Launch Sites across {air_blast} tiles for {raid_s} s. Thins troops, breaks no buildings. Flak can't touch it.",
	slug = "Takes a level off each enemy building along its last {lance_len} tiles. Kills no troops.",
	reinforce = "Calls up {rein_pct}% of your troop cap, then no regrowth for {rein_empty} s. Ready again after {rein_s} s.",
	callarms = "From the Conflict, gold buys {call_pct}% of your troop cap. Each call costs half as much again per troop. Ready again after {call_s} s.",
	farm = "Feeds your realm: more food for your troops at home and at war.",
	market = "Taxes trade in its province: more gold every second.",
	barracks = "Drills recruits: a larger troop cap and manpower that refills faster.",
	fort = "Guards its province: attacks on your land there cost more and take longer, and sieges last longer.",
}
-- (a start date's own descriptions follow the match: Data/PeriodTech)
UICtx.data("PeriodTech").track(UIRules.BLURBS, nil, "blurbs")

--- Godot String.format({key: value}): replaces {key} placeholders.
function UIRules.format(text: string, values: { [string]: string }): string
	return (
		string.gsub(text, "{([%w_]+)}", function(k: string)
			local v = values[k]
			return if v ~= nil then v else "{" .. k .. "}"
		end)
	)
end

--- Blurb with its numbers filled in from Rules.
function UIRules.blurb(kind: string): string
	local R = Rules()
	return UIRules.format(UIRules.BLURBS[kind] or "", {
		city = T().fmt_troops(R.CITY_TROOPS),
		def_r = tostring(Defs.round(R.defense_range())),
		def_mag = tostring(Defs.round(R.DEFENSE_POST_MAG)),
		def_cost = tostring(Defs.round(R.DEFENSE_POST_COST)),
		sam_r = tostring(Defs.round(R.sam_range(1))),
		mirv_n = tostring(R.MIRV_WARHEADS),
		art_r = tostring(Defs.round(R.artillery_range())),
		air_r = tostring(Defs.round(R.launch_range(Defs.N_AIRSTRIKE))),
		air_s = tostring(R.RELOAD_TICKS[Defs.S_AIRFIELD] // Defs.TICK_RATE),
		rail_s = tostring(R.RELOAD_TICKS[Defs.S_RAILGUN] // Defs.TICK_RATE),
		air_blast = tostring(Defs.round(R.NUKE_RADIUS[Defs.N_AIRSTRIKE])),
		scat_lo = tostring(R.SCATTER_MIN),
		scat_hi = tostring(R.SCATTER_MAX),
		rein_s = tostring(R.REINFORCE_COOLDOWN_TICKS // Defs.TICK_RATE),
		rein_pct = tostring(Defs.round(R.REINFORCE_FRACTION * 100)),
		rein_empty = tostring(R.LEVY_EMPTY_TICKS // Defs.TICK_RATE),
		call_pct = tostring(Defs.round(R.CALL_TO_ARMS_FRACTION * 100)),
		call_s = tostring(R.CALL_TO_ARMS_COOLDOWN_TICKS // Defs.TICK_RATE),
		rail_r = tostring(Defs.round(R.launch_range(Defs.N_SLUG))),
		lance_len = tostring(Defs.round(R.LANCE_LINE_FULL)),
		mega_r = tostring(Defs.round(R.NUKE_RADIUS[Defs.N_MEGA])),
		raid_s = tostring(R.RAID_GROUNDED_TICKS // Defs.TICK_RATE),
	})
end

function UIRules.new(c: any)
	local self = setmetatable({}, UIRules)
	self.ctx = c
	-- One-entry cache for primary(): hover card and the following click ask about the same tile.
	self._pc_tile = -1
	self._pc_msec = 0
	self._pc_tick = -1
	self._pc_ratio = -1.0
	self._pc = {} :: { [string]: any }
	-- Local owner's structure counts by kind (index = Defs.S_*) plus warships and transports, kept
	-- current from GameState signals so availability checks are O(1).
	self._scount = table.create(Defs.STRUCT_KIND_COUNT, 0)
	self._scount[0] = 0
	self._warships = 0
	self._transports = 0
	self._counted_owner = -1
	return self
end

--- The Arsenal item (Data/Arsenal) a build / launch kind belongs to; nil for the kinds everyone has.
function UIRules.arsenal_item(kind: string): any
	return Arsenal().item_for(kind)
end

--- True when `kind` is an Arsenal kind the player hasn't unlocked.
function UIRules.arsenal_locked(self: any, kind: string): boolean
	local it = Arsenal().item_for(kind)
	if it == nil then
		return false
	end
	local s = self.ctx.session
	return not (s ~= nil and type(s.has_unlock) == "function" and s:has_unlock(it.key))
end

--- A call: an order that brings troops, not a placement or a launch (the Harvest Levy, the Call to Arms).
function UIRules.is_call(kind: string): boolean
	return kind == "reinforce" or kind == "callarms"
end

--- A strike: a munition its own structure fires (an Air Strike, a Railgun shot), not a silo.
function UIRules.is_strike(kind: string): boolean
	return kind == "airstrike" or kind == "slug"
end

--- The structure kind (Defs.S_*) a nuke / strike kind leaves from.
function UIRules.launcher(kind: string): number
	local nk = Defs.nuke_kind_from_name(kind)
	local l = if nk >= 0 then Rules().NUKE_LAUNCHER[nk] else nil
	return if type(l) == "number" and l >= 0 then l else Defs.S_SILO
end

--- The rate, for the details card: "+" .. render_troops(rate per second) .. "/s"; render_number clamps at 0, so a nation
--- above its cap after losing land reads "+0/s".
function UIRules.troop_rate_text(per_second: number): string
	return "+" .. T().fmt_troops(math.max(per_second, 0.0)) .. "/s"
end

--- The share of the cap at which troops come back fastest, for the gauge's mark (Rules.troop_growth, whose peak sits
--- inside the bar: fewer troops breed slowly, a full army hardly at all).
UIRules.BEST_SHARE_STEPS = 32
function UIRules.best_share(kind: number, cap: number, difficulty: number): number
	local best, best_rate = 0.0, -math.huge
	for i = 1, UIRules.BEST_SHARE_STEPS - 1 do
		local k = i / UIRules.BEST_SHARE_STEPS
		local rate = Rules().troop_growth(kind, cap * k, cap, difficulty)
		if rate > best_rate then
			best, best_rate = k, rate
		end
	end
	return best
end

--- The word for where an army stands against that mark. Pure.
function UIRules.troop_state(troops: number, cap: number, best: number): string
	local share = troops / math.max(cap, 1.0)
	if share >= 0.98 then
		return "Full"
	elseif share < best * 0.85 then
		return "Rising"
	elseif share <= best * 1.15 then
		return "At best"
	end
	return "Slowing"
end

--- Aimed at a target tile and launched (the bombs, and the Arsenal's munitions).
function UIRules.is_nuke(kind: string): boolean
	return kind == "atom"
		or kind == "hydrogen"
		or kind == "mirv"
		or kind == "mega"
		or kind == "scatter"
		or kind == "airstrike"
		or kind == "slug"
end

-- ---------------------------------------------------------------------------------------------
-- Costs (single adapter over Core/Rules)
-- ---------------------------------------------------------------------------------------------

--- `owned`: structures of the kinds that share the cost count, warships for "warship", the
--- player's own MIRVs launched this match for "mirv".
function UIRules.rules_cost(kind: string, owned: number): number
	if UIRules.is_nuke(kind) then
		return Rules().nuke_cost(kind, owned)
	end
	return Rules().build_cost(kind, owned)
end

--- (inner, outer) blast radii in tiles (MIRV: 0, spread) — Rules.nuke_radii. Two numbers.
function UIRules.nuke_radii(kind: string): (number, number)
	local k = Defs.nuke_kind_from_name(kind)
	if k < 0 then
		return 0, 0
	end
	local a, b = Rules().nuke_radii(k)
	if typeof(a) == "Vector2" then
		return a.X, a.Y
	end
	return a or 0, b or 0
end

function UIRules.nuke_radius(kind: string): number
	local _, outer = UIRules.nuke_radii(kind)
	return Defs.round(outer)
end

--- What a blast does, for its card.
function UIRules.blast_text(kind: string): string
	local inner, outer = UIRules.nuke_radii(kind)
	if kind == "mirv" then
		-- MIRV_WARHEADS is the cap: the real count follows the target's land (55-tile spacing)
		return string.format("Up to %d shards, all on one nation", Rules().MIRV_WARHEADS)
	end
	if inner > 0.0 then
		return string.format("Wrecks %d tiles; nothing lives in the middle %d", Defs.round(outer), Defs.round(inner))
	end
	return string.format("Wrecks %d tiles", Defs.round(outer))
end

--- A building by its level: "City", "City II". Roman, like a ruler's. Pure.
local ROMAN = { { 50, "L" }, { 40, "XL" }, { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" } }
function UIRules.level_name(title: string, level: number): string
	if level <= 1 then
		return title
	end
	local n, out = math.floor(level), ""
	for _, r in ROMAN do
		while n >= r[1] do
			out ..= r[2]
			n -= r[1]
		end
	end
	return title .. " " .. out
end

--- The victory metric as result-screen copy (review R2-4): `win` = share of the land outside
--- fallout (what Sim._check_victory compares with Rules.WIN_SHARE), `land` = share of all land.
--- "80.1%" + `all_land` when nothing is irradiated (or it makes no visible difference), else
--- "80.1% of the land outside fallout" -- never a number that reads as short of the 80% goal.
function UIRules.win_phrase(win: number, land: number, fallout: number, all_land: string): string
	local pct = T().fmt_pct(win)
	if fallout > 0 and T().fmt_pct(land) ~= pct then
		return pct .. " of all clean land"
	end
	return pct .. all_land
end

--- Seconds for the result screen's "Match duration" card: the whole match (stats.match_s, set at
--- game over) on a result, the moment the player fell (duration_s) on ELIMINATED (review R2-6).
function UIRules.result_seconds(kind: string, stats: { [string]: any }): number
	local secs = tonumber(stats.duration_s) or 0.0
	local m = tonumber(stats.match_s)
	if kind ~= "eliminated" and m ~= nil then
		secs = m
	end
	return secs
end

--- Full recount (on bind / when the local owner changes). Everything else is incremental.
function UIRules.recount(self: any)
	if self._m ~= nil then
		self._m.state = nil
	end
	self._scount = table.create(Defs.STRUCT_KIND_COUNT, 0)
	self._scount[0] = 0
	self._warships = 0
	self._transports = 0
	local s = self.ctx.state
	local me = self.ctx:me()
	self._counted_owner = me
	if s == nil or me == 0 then
		return
	end
	for _, st in s.structures do
		if st.owner == me and st.kind >= 0 and st.kind < Defs.STRUCT_KIND_COUNT then
			self._scount[st.kind] += 1
		end
	end
	for _, u in s.units do
		if u.owner == me then
			if u.kind == Defs.U_WARSHIP then
				self._warships += 1
			elseif u.kind == Defs.U_TRANSPORT then
				self._transports += 1
			end
		end
	end
end

--- Structure moved between owners (old -> new); returns true when the local owner is involved.
function UIRules.on_structure(self: any, kind: number, old_owner: number, new_owner: number): boolean
	local me = self.ctx:me()
	if me == 0 or kind < 0 or kind >= Defs.STRUCT_KIND_COUNT then
		return false
	end
	if self._m ~= nil then
		self._m.state = nil
	end
	if self._counted_owner ~= me then
		self:recount()
		return true
	end
	local hit = false
	if old_owner == me then
		self._scount[kind] = math.max(0, self._scount[kind] - 1)
		hit = true
	end
	if new_owner == me then
		self._scount[kind] += 1
		hit = true
	end
	return hit
end

--- Unit added (+1) or removed (-1); returns true when it is ours.
function UIRules.on_unit(self: any, kind: number, owner_id: number, delta: number): boolean
	local me = self.ctx:me()
	if me == 0 or owner_id ~= me then
		return false
	end
	if self._counted_owner ~= me then
		self:recount()
		return true
	end
	if kind == Defs.U_WARSHIP then
		self._warships = math.max(0, self._warships + delta)
	elseif kind == Defs.U_TRANSPORT then
		self._transports = math.max(0, self._transports + delta)
	end
	return true
end

function UIRules.struct_count(self: any, kind: number): number
	if self._counted_owner ~= self.ctx:me() then
		self:recount()
	end
	return if kind >= 0 and kind < Defs.STRUCT_KIND_COUNT then self._scount[kind] else 0
end

function UIRules.transports(self: any): number
	if self._counted_owner ~= self.ctx:me() then
		self:recount()
	end
	return self._transports
end

function UIRules.owned(self: any, kind: string): number
	local ctx = self.ctx
	if ctx.state == nil or ctx:me() == 0 then
		return 0
	end
	if self._counted_owner ~= ctx:me() then
		self:recount()
	end
	if kind == "warship" then
		return self._warships
	end
	if kind == "mirv" then
		return Rules().mirvs_of(ctx.state, ctx:me())
	end
	if UIRules.is_nuke(kind) or UIRules.is_call(kind) then
		return 0
	end
	-- Ports and factories share one count (Rules.cost_count_kinds).
	local n = 0
	for _, sk in Rules().cost_count_kinds(kind) do
		n += self:struct_count(sk)
	end
	return n
end

--- The local player's structures by kind, from one pass over the match's, kept while the frame is
--- the same (state, tick, render tick and owner): per kind (index kind + 1) the level sum, the
--- finished and building counts, the seconds until the first one building finishes, and the
--- structures themselves. (2026-10-27: the build slots refresh 2-4 times a second and each slot made
--- its own passes, ~17 over every structure in the match per refresh: costs, silos, launchers. The
--- answers are the same.)
function UIRules._mine(self: any, s: any): any
	local me = self.ctx:me()
	local m = self._m
	if m == nil then
		local n = Defs.STRUCT_KIND_COUNT
		m = { level = table.create(n, 0), act = table.create(n, 0), building = table.create(n, 0) }
		m.soonest = table.create(n, math.huge)
		m.list = {}
		for k = 1, n do
			m.list[k] = {}
		end
		self._m = m
	elseif m.state == s and m.tick == s.tick and m.rt == s.render_tick and m.me == me then
		return m
	end
	m.state, m.tick, m.rt, m.me = s, s.tick, s.render_tick, me
	local level, act, building, soonest, list = m.level, m.act, m.building, m.soonest, m.list
	for k = 1, Defs.STRUCT_KIND_COUNT do
		level[k], act[k], building[k], soonest[k] = 0, 0, 0, math.huge
		table.clear(list[k])
	end
	local tick = s.tick
	for _, st in s.structures do
		local k = st.kind
		if st.owner ~= me or k < 0 or k >= Defs.STRUCT_KIND_COUNT then
			continue
		end
		k += 1
		level[k] += st.level
		if st.active_tick > tick then
			building[k] += 1
			soonest[k] = math.min(soonest[k], (st.active_tick - tick) / Defs.TICK_RATE)
		else
			act[k] += 1
		end
		table.insert(list[k], st)
	end
	return m
end

--- What Rules.cost_of reads the state through: the local player's level sums from _mine, the rest
--- from the state itself.
function UIRules._cost_view(self: any, s: any): any
	local view = self._view
	if view == nil then
		local mt = { __index = s }
		view = setmetatable({
			struct_level_sum = function(_, id: number, kind: number): number
				local st = mt.__index
				if id == self.ctx:me() and kind >= 0 and kind < Defs.STRUCT_KIND_COUNT then
					return self:_mine(st).level[kind + 1]
				end
				return st:struct_level_sum(id, kind)
			end,
		}, mt)
		self._view, self._view_mt = view, mt
	end
	self._view_mt.__index = s
	return view
end

--- Gold for the next `kind` (structures, upgrades, warships, nukes) — Rules.cost_of, the Sim's
--- own pricing (shared port/factory count, levels, the player's own MIRV launches).
function UIRules.cost(self: any, kind: string): number
	local ctx = self.ctx
	if kind == "reinforce" then
		return Rules().REINFORCE_COST
	end
	if kind == "callarms" then
		-- (per troop, rising with each call this match: the Sim's own Rules.call_cost)
		local s, o = ctx.state, ctx:my()
		if s == nil or o == nil then
			return 0
		end
		return Rules().call_cost((s.call_n and s.call_n[o.id]) or 0, o.troops or 0, o.max_troops or 0)
	end
	if ctx.state == nil then
		return UIRules.rules_cost(kind, 0)
	end
	return Rules().cost_of(self:_cost_view(ctx.state), ctx:me(), kind)
end

--- The local player's finished structures of `kind` that can fire now (a silo's loaded missiles, an
--- airfield / railgun that isn't reloading), and the seconds until the next one can when none does.
function UIRules.ready_launchers(self: any, kind: number): (number, number)
	local s = self.ctx.state
	if s == nil then
		return 0, 0.0
	end
	local cd = Rules().RELOAD_TICKS[kind] or 0
	local n = 0
	local soonest = math.huge
	local mine = if kind >= 0 and kind < Defs.STRUCT_KIND_COUNT then self:_mine(s).list[kind + 1] else {}
	for _, st in mine do
		if st.active_tick <= s.tick then
			local busy = 0
			local first = math.huge
			for _, t in st.shots or {} do
				if t + cd > s.tick then
					busy += 1
					first = math.min(first, t + cd - s.tick)
				end
			end
			local free = math.max(0, (st.level or 1) - busy)
			n += free
			if free == 0 then
				soonest = math.min(soonest, first)
			end
		end
	end
	return n, if n == 0 and soonest < math.huge then soonest / Defs.TICK_RATE else 0.0
end

--- Finished (active) structures of `kind` the local player owns — silos must be built before a
--- nuke can fly. Returns active, under_construction, seconds until the first one finishes.
function UIRules.active_structs(self: any, kind: number): (number, number, number)
	local s = self.ctx.state
	if s == nil or kind < 0 or kind >= Defs.STRUCT_KIND_COUNT then
		return 0, 0, 0.0
	end
	local m = self:_mine(s)
	local k = kind + 1
	local building = m.building[k]
	return m.act[k], building, if building > 0 then m.soonest[k] else 0.0
end

--- {ok, locked, reason, cost} — whether the action can be used right now (ignores the target).
function UIRules.availability(self: any, kind: string): { [string]: any }
	local ctx = self.ctx
	local c = self:cost(kind)
	local out = { ok = false, locked = false, reason = "", cost = c } :: { [string]: any }
	local s = ctx.state
	local o = ctx:my()
	-- a start date without it (Data/PeriodTech: no bombs in the Middle Ages): dimmed, its card says so; before the
	-- Arsenal's lock, so a War College kind the date never has is not offered for sale either
	local st0 = self.ctx ~= nil and self.ctx.state or nil
	if st0 ~= nil and UICtx.data("PeriodTech").closed(st0.period, kind) then
		out.reason = string.format("Not in %s", tostring(st0.period))
		out.locked = true
		return out
	end
	-- an Arsenal kind the player hasn't unlocked: `arsenal` names the item to offer
	if self:arsenal_locked(kind) then
		local it = UIRules.arsenal_item(kind)
		out.reason = "Learn it at the War College: " .. it.title
		out.locked = true
		out.arsenal = it.key
		return out
	end
	if s == nil or o == nil or not ctx:in_match() then
		out.reason = "There is no war yet"
		out.locked = true
		return out
	end
	-- (Farms, Markets, Barracks and Forts: a depth match only, docs/DEPTH_DESIGN.md)
	if UICtx.core("Defs").DEPTH_KINDS[kind] and s.depth == nil then
		out.reason = "Long and Quick wars only"
		out.locked = true
		out.hidden = true
		return out
	end
	-- a building whose age has not come (the Sim holds to the same table): dimmed, and its card names the age
	if s.eras ~= nil and not UIRules.is_nuke(kind) and not UIRules.is_call(kind) then
		local Eras = UICtx.data("Eras")
		local since = if (s.playing_since or -1) >= 0 then ctx:render_tick() - s.playing_since else 0
		if not Eras.build_open(kind, Eras.index(since, s.eras)) then
			out.reason = Eras.opens_text(kind)
			out.locked = true
			out.opens = Eras.NAMES[Eras.opens_in(kind)]
			return out
		end
	end
	if not o.spawned then
		out.reason = "Plant your banner first"
		out.locked = true
		return out
	end
	if not o.alive then
		out.reason = "Your banner is down"
		out.locked = true
		return out
	end
	if s.phase ~= Defs.PHASE_PLAYING then
		out.reason = "Not until landfall is over"
		out.locked = true
		return out
	end
	if UIRules.is_nuke(kind) then
		-- the structure it leaves from: a silo, or (strikes) an aerodrome / a railgun
		local lk = UIRules.launcher(kind)
		local title = Defs.STRUCT_TITLES[lk]
		if self:struct_count(lk) == 0 then
			out.reason = "First build " .. (if lk == Defs.S_AIRFIELD then "an " else "a ") .. title
			out.locked = true
			return out
		end
		local act, _, soon = self:active_structs(lk)
		if act == 0 then
			local what = if lk == Defs.S_SILO then "Launch Site" else title
			out.reason = what .. " still going up · ready in " .. T().fmt_time(math.ceil(soon))
			out.locked = true
			return out
		end
		if UIRules.is_strike(kind) then
			local ready, wait = self:ready_launchers(lk)
			if ready == 0 then
				out.reason = string.format(
					"%s · back in %s",
					if lk == Defs.S_AIRFIELD then "Aerodrome refuelling" else "Lance Cannon reloading",
					T().fmt_time(math.ceil(wait))
				)
				return out
			end
		end
	end
	if kind == "callarms" then
		local since = if (s.playing_since or -1) >= 0 then ctx:render_tick() - s.playing_since else 0
		if not Rules().call_open(since, s.eras) then
			-- (a match without ages opens it when the Conflict would come: no age to name)
			local age = if s.eras ~= nil then UICtx.data("Eras").NAMES[Rules().CALL_TO_ARMS_AGE] else nil
			out.reason = if age ~= nil then "Opens in the " .. age else "Opens later in the war"
			out.locked = true
			out.opens = age
			return out
		end
		local wait = ((s.call_ready and s.call_ready[o.id]) or 0) - s.tick
		if wait > 0 then
			out.reason = "Back in " .. T().fmt_time(math.ceil(wait / Defs.TICK_RATE))
			return out
		end
		if Rules().call_troops(o.troops or 0, o.max_troops or 0) <= 0 then
			out.reason = "Your army is full"
			return out
		end
	end
	if kind == "reinforce" then
		local wait = ((s.reinforce_ready and s.reinforce_ready[o.id]) or 0) - s.tick
		if wait > 0 then
			out.reason = "Back in " .. T().fmt_time(math.ceil(wait / Defs.TICK_RATE))
			return out
		end
		if Rules().reinforce_troops(o.troops or 0, o.max_troops or 0) <= 0 then
			out.reason = "Your army is full"
			return out
		end
	end
	if kind == "port" and not ctx.borders:has_coast() then
		out.reason = "You need a coast for this"
		out.locked = true
		return out
	end
	if kind == "warship" and self:struct_count(Defs.S_PORT) == 0 then
		out.reason = "First build a Harbor"
		out.locked = true
		return out
	end
	if kind == "warship" then
		local act, _, soon = self:active_structs(Defs.S_PORT)
		if act == 0 then
			out.reason = "Harbor still going up · ready in " .. T().fmt_time(math.ceil(soon))
			out.locked = true
			return out
		end
	end
	if c < 0 then
		out.reason = "Not possible now"
		out.locked = true
		return out
	end
	if (o.gold or 0) < c then
		out.reason = "Short by " .. T().fmt_num(c - o.gold) .. " gold"
		return out
	end
	out.ok = true
	return out
end

--- Structure kinds an own structure of the same kind upgrades instead of a new build (defense posts
--- are not upgradable).
UIRules.UPGRADABLE = { "city", "port", "factory", "sam", "silo" }

--- Amounts on the order card: one, half of what you can have, or all of it (capped by gold, and for warheads by loaded
--- Launch Sites; Protocol.MAX_INTENT_AMOUNT 50).
UIRules.MAX_BULK = 50

--- Missiles loaded right now in the local player's finished silos (a silo holds one per level;
--- each launch reloads for SILO_COOLDOWN_TICKS).
function UIRules.ready_missiles(self: any): number
	local s = self.ctx.state
	if s == nil then
		return 0
	end
	local me = self.ctx:me()
	local cd = Rules().SILO_COOLDOWN_TICKS
	local n = 0
	for _, st in s.structures do
		if st.owner == me and st.kind == Defs.S_SILO and st.active_tick <= s.tick then
			local busy = 0
			for _, t in st.shots or {} do
				if t + cd > s.tick then
					busy += 1
				end
			end
			n += math.max(0, (st.level or 1) - busy)
		end
	end
	return n
end

--- Total gold for `amount` more of `kind` in a row (upgrades: each level at the next price).
function UIRules.bulk_cost(self: any, kind: string, amount: number): number
	local R = Rules()
	if UIRules.is_nuke(kind) then
		return R.nuke_cost(kind, if self.ctx.state then R.mirvs_of(self.ctx.state, self.ctx:me()) else 0) * amount
	end
	local count = if self.ctx.state then R.cost_count_of(self.ctx.state, self.ctx:me(), kind) else 0
	local total = 0
	for i = 0, amount - 1 do
		total += R.build_cost(kind, count + i)
	end
	return total
end

--- The most of `kind` the local player can buy in a row now (gold; bombs: loaded missiles too).
function UIRules.bulk_max(self: any, kind: string): number
	local o = self.ctx:my()
	local gold = if o ~= nil then (tonumber(o.gold) or 0) else 0
	local cap = UIRules.MAX_BULK
	if UIRules.is_nuke(kind) then
		cap = math.min(cap, self:ready_missiles())
	end
	local max = 0
	for n = 1, cap do
		if self:bulk_cost(kind, n) > gold then
			break
		end
		max = n
	end
	return max
end

--- The amount ring for `kind` (id prefix "build" / "nuke") when more than one is possible, else nil.
function UIRules.bulk_ring(self: any, prefix: string, kind: string): { any }?
	local max = self:bulk_max(kind)
	if max <= 1 then
		return nil
	end
	local half = math.ceil(max / 2)
	local slots = if half > 1 and half < max then { 1, half, max } else { 1, max }
	local ring = {}
	local nuke = UIRules.is_nuke(kind)
	local loaded = if nuke then self:ready_missiles() else math.huge
	for i, n in slots do
		local cost = self:bulk_cost(kind, n)
		local ok = n <= max
		local reason = ""
		if not ok then
			reason = if nuke and n > loaded
				then string.format("%d ready to fly", loaded)
				else "Too little gold"
		end
		table.insert(ring, {
			id = string.format("%s:%s:%d", prefix, kind, n),
			-- (the last is all you can have: it says how many)
			label = if i == #slots
				then string.format("All %d · %s", n, T().fmt_cost(cost))
				elseif n == 1 then string.format("One · %s", T().fmt_cost(cost))
				else string.format("%d · %s", n, T().fmt_cost(cost)),
			icon = kind,
			ok = ok,
			reason = reason,
			danger = nuke,
			cost = cost,
		})
	end
	return ring
end

--- A Rules constant by name (so the UI works before and after the Sim exposes it).
function UIRules.rules_const(cname: string, fallback: any): any
	local v = Rules()[cname]
	if v == nil then
		return fallback
	end
	return v
end

--- Radius (our tiles) a build tap searches the player's own land for a valid site
--- (15 full-size tiles).
function UIRules.snap_radius(): number
	return tonumber(UIRules.rules_const("BUILD_SNAP_RADIUS", 15.0 / Rules().K_LIN)) :: number
end

--- Friendly copy for Rules.placement reasons.
UIRules.PLACE_REASONS = {
	not_own = "Not yours to build on",
	no_room = "Another building stands here",
	no_coast = "A Harbor goes on your shore",
	no_port = "No Harbor of yours is ready on this water",
	gold = "Too little gold",
	invalid = "You can't raise that here",
	locked = "Its age has not come",
}

--- Where a build tap at `tile` really lands:
---   * near an own structure of the same upgradable kind -> upgrade it (tile = that structure);
---   * else the nearest valid site on the player's own land connected to the tap, within
---     snap_radius(), at least STRUCT_MIN_DIST from every structure of any owner (ports: coast).
--- Nukes and warships aim exactly. Returns {ok, tile, reason, warn, upgrade, sid, level}.
function UIRules.resolve_placement(self: any, kind: string, tile: number): { [string]: any }
	local ctx = self.ctx
	local out =
		{ ok = false, tile = tile, reason = "", warn = "", upgrade = false, sid = 0, level = 1 } :: { [string]: any }
	local s = ctx.state
	if s == nil or tile < 0 then
		out.reason = "Aim at land or sea"
		return out
	end
	if UIRules.is_nuke(kind) then
		local pl = self:_placement_exact(kind, tile)
		out.ok = pl.ok
		out.reason = pl.reason
		out.warn = pl.warn
		return out
	end
	-- The Sim's own algorithm (Rules.place_site via Rules.placement): snapped site or upgrade.
	local r = Rules().placement(s, ctx:me(), kind, tile)
	local code = tostring(r.reason or "")
	local rtile = tonumber(r.tile) or -1
	if kind == "warship" then
		-- the tap picks the patrol target on the sea; Rules returns the launching port.
		out.port = rtile
		out.ok = code == "" and s.map:is_water(tile)
		out.tile = tile
		out.code = code
		if code == "" and not s.map:is_water(tile) then
			out.reason = "Pick the water you want the Frigate to guard"
		elseif code ~= "" then
			out.reason = UIRules.PLACE_REASONS[code] or "You can't raise that here"
		end
		return out
	end
	-- (a depth match: a new building needs a free slot in its province, as the Sim checks: SimProvinces)
	local ds = s.depth
	if ds ~= nil and (code == "" or code == "gold") and rtile >= 0 and (tonumber(r.upgrade_sid) or 0) == 0 then
		local p = ds:province_at(rtile)
		if p > 0 and ds:slots_used(p) >= ds.P.slots[p] then
			code = "no_slot"
		end
	end
	-- Gold is shown on the slot itself; the preview still shows where it would go.
	out.ok = code == "" or code == "gold"
	out.tile = if rtile >= 0 then rtile else tile
	out.reason = if code == "no_slot" then string.format("%s has no free building slot", ds.P.name[ds:province_at(rtile)] or "This province")
		elseif code ~= "" then (UIRules.PLACE_REASONS[code] or "You can't raise that here")
		else ""
	out.code = code
	local sid = tonumber(r.upgrade_sid) or 0
	if sid > 0 and s.structures[sid] ~= nil then
		out.upgrade = true
		out.sid = sid
		out.level = s.structures[sid].level + 1
	end
	if code == "gold" then
		out.ok = false
	end
	return out
end

--- {ok, reason, warn, tile, upgrade, level} for placing `kind` at `tile` (availability is checked
--- separately). Structures snap / upgrade like the Sim (resolve_placement).
function UIRules.placement(self: any, kind: string, tile: number): { [string]: any }
	if UIRules.is_nuke(kind) then
		return self:_placement_exact(kind, tile)
	end
	return self:resolve_placement(kind, tile)
end

--- True when a finished structure of `skind` of the local player's that can fire now is within the
--- reach of munition `nkind` from `tile` (no reach limit: any such structure).
function UIRules.in_reach(self: any, skind: number, nkind: number, tile: number): boolean
	local s = self.ctx.state
	if s == nil then
		return false
	end
	local R = s.rules or Rules()
	local me = self.ctx:me()
	local reach = R.launch_range(nkind)
	local cd = R.RELOAD_TICKS[skind] or 0
	local range_d2 = s.map.range_d2
	for _, st in s.structures do
		if st.owner == me and st.kind == skind and st.active_tick <= s.tick then
			local busy = 0
			for _, t in st.shots or {} do
				if t + cd > s.tick then
					busy += 1
				end
			end
			if busy < (st.level or 1) and (reach <= 0 or range_d2(st.tile, tile) <= reach * reach) then
				return true
			end
		end
	end
	return false
end

function UIRules._placement_exact(self: any, kind: string, tile: number): { [string]: any }
	local ctx = self.ctx
	local out = { ok = false, reason = "", warn = "" } :: { [string]: any }
	local s = ctx.state
	if s == nil or tile < 0 then
		out.reason = "Aim at land or sea"
		return out
	end
	local map = s.map
	local own = s:tile_owner(tile)
	local me = ctx:me()
	if UIRules.is_nuke(kind) then
		if own == me and own ~= 0 then
			out.reason = "Not on your own ground"
			return out
		end
		if not map:is_land(tile) and kind ~= "mirv" then
			out.warn = "Open water: the blast is wasted"
		end
		if own ~= 0 and s:are_allies(me, own) then
			out.warn = "Your oath to " .. s:owner_name(own) .. " breaks with this"
		end
		if kind == "mirv" and own == 0 then
			out.reason = "Aim at a nation"
			return out
		end
		if UIRules.is_strike(kind) then
			-- a strike never hits an ally, and an air strike needs a ready airfield within reach
			out.warn = ""
			if own ~= 0 and s:are_allies(me, own) then
				out.reason = "That land is under your oath"
				return out
			end
			if kind == "airstrike" and not self:in_reach(Defs.S_AIRFIELD, Defs.N_AIRSTRIKE, tile) then
				out.reason = "Your Aerodromes can't reach that"
				return out
			end
			if kind == "slug" and not self:in_reach(Defs.S_RAILGUN, Defs.N_SLUG, tile) then
				out.reason = "Your Lance Cannons can't reach that"
				return out
			end
			if own == 0 then
				out.warn = "Nobody holds this: the raid is wasted"
			end
		end
		out.ok = true
		return out
	end
	if kind == "warship" then
		if map:is_water(tile) or own == me then
			out.ok = true
		else
			out.reason = "Pick water your Harbors can reach"
		end
		return out
	end
	if own ~= me then
		out.reason = "Build on ground you hold"
		return out
	end
	if kind == "port" and not map:is_coastal(tile) then
		out.reason = "A Harbor needs a shore"
		return out
	end
	-- Same test as the Sim: no structure closer than STRUCT_MIN_DIST (latitude-corrected circle).
	local md = Rules().STRUCT_MIN_DIST
	local min_d2 = md * md
	local range_d2 = Defs.range_d2
	for _, st in s.structures do
		if range_d2(tile, st.tile) < min_d2 then
			out.reason = "Another building stands here"
			return out
		end
	end
	out.ok = true
	return out
end

-- ---------------------------------------------------------------------------------------------
-- Primary click
-- ---------------------------------------------------------------------------------------------

--- What a primary click on `tile` does:
--- Where a boat aimed at `tile` lands — the
--- nearest coastal tile of the same owner (unclaimed land for owner 0) that one of our coasts
--- reaches by sea, so clicking anywhere on a territory across the water works, not only its shore
--- pixel. Searches rings out to BOAT_SNAP_FULL full-size tiles; -1 when none.
UIRules.BOAT_SNAP_FULL = 120.0
function UIRules.boat_landing(self: any, tile: number): number
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or tile < 0 then
		return -1
	end
	local map = s.map
	local borders = ctx.borders
	if map:is_coastal(tile) and borders:can_reach_by_sea(tile) then
		return tile
	end
	local own = s:tile_owner(tile)
	local W, H = map.W, map.H
	local k = tonumber(map.k_lin) or 1.0
	local rmax = math.ceil(UIRules.BOAT_SNAP_FULL / k)
	local cx, cy = tile % W, tile // W
	local best, best_d = -1, math.huge
	for r = 1, rmax do
		-- the ring at Chebyshev distance r
		for dy = -r, r do
			local y = cy + dy
			if y < 0 or y >= H then
				continue
			end
			local edge = dy == -r or dy == r
			local dx = -r
			while dx <= r do
				local x = cx + dx
				if x >= 0 and x < W then
					local t = y * W + x
					if map:is_coastal(t) and s:tile_owner(t) == own and borders:can_reach_by_sea(t) then
						local d = dx * dx + dy * dy
						if d < best_d then
							best, best_d = t, d
						end
					end
				end
				dx += if edge then 1 else 2 * r
			end
		end
		-- a hit on ring r: nothing farther than r * sqrt(2) can be closer
		if best >= 0 and r * r >= best_d / 2 then
			break
		end
	end
	return best
end

--- {type: spawn|expand|attack|boat|inspect|none, ok, reason, target, troops, verb, icon}
function UIRules.primary(self: any, tile: number): { [string]: any }
	local ctx = self.ctx
	local now = UICtx.msec()
	local t = if ctx.state ~= nil then ctx.state.tick else -1
	if
		tile == self._pc_tile
		and now - self._pc_msec < 400
		and t == self._pc_tick
		and math.abs(ctx.ratio - self._pc_ratio) < 1e-6
	then
		return table.clone(self._pc)
	end
	local res = self:_primary(tile)
	self._pc_tile = tile
	self._pc_msec = now
	self._pc_tick = t
	self._pc_ratio = ctx.ratio
	self._pc = res
	return table.clone(res)
end

--- Drops the primary() cache (tests / after the world changed under the same tick).
function UIRules.invalidate(self: any)
	self._pc_tile = -1
end

function UIRules._primary(self: any, tile: number): { [string]: any }
	local ctx = self.ctx
	local out =
		{ type = "none", ok = false, reason = "", target = 0, troops = 0.0, verb = "", icon = "info" } :: { [string]: any }
	local s = ctx.state
	if s == nil or tile < 0 or tile >= Defs.TILE_COUNT then
		return out
	end
	local map = s.map
	local me = ctx:me()
	local own = s:tile_owner(tile)
	out.target = own
	if me == 0 or not ctx:in_match() then
		out.type = "inspect"
		out.ok = own ~= 0
		return out
	end
	local o = ctx:my()
	if s.phase == Defs.PHASE_SPAWN or ctx:needs_spawn() then
		if o ~= nil and o.spawned and own == me then
			out.type = "inspect"
			out.ok = true
			return out
		end
		if map:is_contestable(tile) and own == 0 and not s:has_fallout(tile) then
			out.type = "spawn"
			out.ok = true
			out.verb = "Plant here"
			out.icon = "target"
		else
			-- (name what is there)
			out.reason = if own ~= 0 then s:owner_name(own) .. " holds this" else "Banners need dry land"
		end
		return out
	end
	if s.phase ~= Defs.PHASE_PLAYING or o == nil or not o.alive then
		out.type = "inspect"
		out.ok = own ~= 0
		return out
	end
	if own == me or (own ~= 0 and s:are_allies(me, own)) then
		out.type = "inspect"
		out.ok = true
		return out
	end
	if not map:is_contestable(tile) then
		out.reason = if ctx:terrain_at(tile) == Defs.T_ICECAP then "Nobody can hold Antarctica" else ""
		return out
	end
	-- Fallout stays until the land is conquered again; taking it is slow and costly.
	local fallout = own == 0 and s:has_fallout(tile)
	local share = ctx:order_ratio()
	local troops = (o.troops or 0) * share
	out.troops = troops
	if troops < 1.0 then
		-- (the floor under a new player's army: UICtx.troop_floor)
		out.floor = share < ctx.ratio
		out.reason = if out.floor then UICtx.data("Tutorial").FLOOR_REASON else "Nobody left to send"
		return out
	end
	local land = false
	if s:borders_tile(me, tile) then
		land = true
	elseif own == 0 then
		local touch = ctx.borders:region_touches_me(tile)
		land = touch == 1 or (touch == -1 and ctx.borders:borders_owner(0))
	else
		land = ctx.borders:borders_owner(own)
	end
	if land then
		out.type = if own == 0 then "expand" else "attack"
		out.ok = true
		out.verb = if own == 0 then (if fallout then "Take the poisoned ground" else "Claim") else "Attack"
		out.icon = "attack"
		return out
	end
	local landing = self:boat_landing(tile)
	if landing >= 0 then
		out.boat_tile = landing
		local max_boats = Rules().MAX_BOATS_PLAYER
		if self:transports() >= max_boats then
			out.type = "boat"
			out.reason = string.format("Your %d landings are all out", max_boats)
			out.icon = "boat"
			return out
		end
		out.type = "boat"
		out.ok = true
		out.verb = "Landing"
		out.icon = "boat"
		return out
	end
	out.reason = if own == 0 then "Your border must reach it first" else "No way in by land or sea"
	return out
end

function UIRules.primary_intent(self: any, tile: number, action: { [string]: any }): { [string]: any }
	local ty = tostring(action.type or "")
	if ty == "spawn" then
		return { type = "spawn", tile = tile }
	elseif ty == "expand" or ty == "attack" then
		return { type = "attack", tile = tile, ratio = self.ctx:order_ratio() }
	elseif ty == "boat" then
		return { type = "boat", tile = tonumber(action.boat_tile) or tile, ratio = self.ctx:order_ratio() }
	end
	return {}
end

--- What changed, for the note beside the order ("Brazil: front opened · 40%"). The number is on the spine.
function UIRules.confirm_text(self: any, action: { [string]: any }): string
	local s = self.ctx.state
	local name = UICtx.ratio_name(self.ctx.ratio)
	local target = tonumber(action.target) or 0
	local ty = tostring(action.type or "")
	if ty == "spawn" then
		return "Your banner stands"
	elseif ty == "expand" then
		return "Claim under way · " .. name
	elseif ty == "attack" then
		local me = self.ctx:me()
		for _, a in s.attacks or {} do
			if a.attacker == me and a.target == target then
				return string.format("%s: front pressed · %s", s:owner_name(target), name)
			end
		end
		return string.format("%s: front opened · %s", s:owner_name(target), name)
	elseif ty == "boat" then
		if target == 0 then
			return "Landing away · " .. name
		end
		return string.format("Landing bound for %s · %s", s:owner_name(target), name)
	end
	return ""
end

-- ---------------------------------------------------------------------------------------------
-- Radial menu
-- ---------------------------------------------------------------------------------------------

--- Items: {id, label, icon, ok, reason, danger, sub: {items}}
--- A donation to ally `own` at the current attack ratio, limited to the ally's troop headroom.
--- The Sim accepts any amount (rule unchanged), but troops above the cap evaporate on the next tick
--- (Rules.troop_growth snaps to the cap), so the UI never sends more than fits (review P1-5).
--- Returns { amount, want, room, cap, capped (amount < want), full (no useful room: < 1 % of cap) }.
function UIRules.donate_plan(self: any, own: number): { [string]: any }
	local ctx = self.ctx
	local want = Defs.trunc(ctx:troops_for_ratio())
	local s = ctx.state
	local o = if s ~= nil and own ~= 0 then s:get_owner(own) else nil
	local cap = if o ~= nil then (tonumber(o.max_troops) or 0) else 0
	local room = want
	if cap > 0 then
		room = math.max(0, math.floor(cap - (tonumber(o.troops) or 0)))
	end
	local amount = math.max(0, math.min(want, room))
	return {
		amount = amount,
		want = want,
		room = room,
		cap = cap,
		capped = amount < want,
		full = cap > 0 and room < math.max(1.0, cap * 0.01),
	}
end

--- The order card's weight of each order, by what you mean to do: act on the target, deal with it, reach it another way,
--- then strike it. An order that can't be given sinks below those that can.
UIRules.ORDER_WEIGHT = {
	attack = 1,
	ally_accept = 1,
	ally_extend = 1,
	donate = 2,
	retreat = 2,
	ally_request = 3,
	boat = 4,
	nuke = 5,
	ally_break = 6,
}

--- `items` (radial_items, or a sub-list) in the order card's order; `items` itself is left alone. A sub-list of
--- amounts runs largest first. Stable: orders of one weight keep their order.
function UIRules.order_items(items: { { [string]: any } }): { { [string]: any } }
	local ranked = {}
	for i, it in items do
		local id = tostring(it.id or "")
		local weight = UIRules.ORDER_WEIGHT[id] or 10
		local amount = tonumber(string.match(id, "^%a+:[%w_]+:(%d+)$") or "")
		if amount ~= nil then
			weight = -amount
		end
		if it.ok ~= true then
			weight += 100
		end
		ranked[i] = { it = it, weight = weight, at = i }
	end
	table.sort(ranked, function(a, b)
		if a.weight ~= b.weight then
			return a.weight < b.weight
		end
		return a.at < b.at
	end)
	local out = {}
	for i, r in ranked do
		out[i] = r.it
	end
	return out
end

--- What a row of the order card says after its name: why not, the cost, or what would go ("2.4k · 40%").
--- `ratio`: the Send bar's share; `sends`: the troops an order sends now.
function UIRules.order_detail(it: { [string]: any }, ratio: number, sends: number): string
	if it.ok ~= true then
		return tostring(it.reason or "")
	end
	local id = tostring(it.id or "")
	if string.match(id, "^%a+:[%w_]+:%d+$") ~= nil then
		return "" -- (a bulk row's label has its amount and price)
	end
	if it.cost ~= nil then
		return T().fmt_cost(it.cost) .. " gold"
	end
	if id == "donate" and it.troops ~= nil then
		return if it.capped
			then T().fmt_troops(it.troops) .. " · fills their ranks"
			else string.format("%s · %s", T().fmt_troops(it.troops), UICtx.ratio_name(ratio))
	end
	if id == "attack" or id == "boat" then
		return string.format("%s · %s", T().fmt_troops(sends), UICtx.ratio_name(ratio))
	end
	return ""
end

function UIRules.radial_items(self: any, tile: number): { { [string]: any } }
	local ctx = self.ctx
	local items = {}
	local s = ctx.state
	if s == nil or tile < 0 then
		return items
	end
	local me = ctx:me()
	local own = s:tile_owner(tile)
	local playing = s.phase == Defs.PHASE_PLAYING and ctx:alive_player() and not ctx:needs_spawn()
	local land = s.map:is_contestable(tile)

	if playing and land and own ~= me and not s:are_allies(me, own) then
		local p = self:primary(tile)
		local is_boat = tostring(p.type) == "boat"
		local verb = if own == 0 then "Claim" else "March"
		-- (no way over land: the row is the way there is, a landing)
		if not is_boat then
			table.insert(items, {
				id = "attack",
				label = verb,
				icon = "attack",
				ok = p.ok,
				reason = if p.ok then "" else tostring(p.reason),
				danger = false,
			})
		end
		local boat = { id = "boat", label = "Send a landing", icon = "boat", ok = false, reason = "", danger = false }
		if self:boat_landing(tile) >= 0 then
			if self:transports() >= Rules().MAX_BOATS_PLAYER then
				boat.reason = "Your landings are all out"
			elseif ctx:troops_for_ratio() < 1.0 then
				boat.reason = "Your army is out"
			else
				boat.ok = true
			end
			table.insert(items, boat)
		end
	end

	if playing and own ~= me and me ~= 0 then
		for _, a in s.attacks do
			if a.attacker == me and a.target == own then
				table.insert(
					items,
					{ id = "retreat", label = "Recall", icon = "retreat", ok = true, reason = "", danger = false }
				)
				break
			end
		end
	end

	if playing and own == me then
		-- what can be built here now, as rows of their own (an age away is no choice yet); the War College's come last
		local build_kinds = table.clone(UIRules.BUILD_KINDS)
		for _, k in UIRules.ARSENAL_BUILD do
			if not self:arsenal_locked(k) then
				table.insert(build_kinds, k)
			end
		end
		for _, k in build_kinds do
			local av = self:availability(k)
			if av.opens == nil then
				local pl = self:placement(k, tile)
				local ok = av.ok and pl.ok
				local reason = if not av.ok then tostring(av.reason) else tostring(pl.reason)
				table.insert(items, {
					id = "build:" .. k,
					label = UIRules.TITLES[k],
					icon = k,
					ok = ok,
					reason = reason,
					danger = false,
					cost = av.cost,
					-- an existing building here: raise it several levels at once
					sub = if ok and pl.upgrade then self:bulk_ring("build", k) else nil,
				})
			end
		end
	end

	-- what can be launched at the tile: the bombs with a silo, and the Arsenal's munitions the player
	-- has unlocked (a strike with its own structure)
	local launch_kinds = {}
	if playing and own ~= me and me ~= 0 then
		local kinds = table.clone(UIRules.NUKE_KINDS)
		for _, k in UIRules.ARSENAL_NUKES do
			if not self:arsenal_locked(k) then
				table.insert(kinds, k)
			end
		end
		for _, k in kinds do
			if self:struct_count(UIRules.launcher(k)) > 0 then
				table.insert(launch_kinds, k)
			end
		end
	end
	if #launch_kinds > 0 then
		local nsub = {}
		for _, k2 in launch_kinds do
			local av2 = self:availability(k2)
			local pl2 = self:placement(k2, tile)
			local ok2 = av2.ok and pl2.ok
			table.insert(nsub, {
				id = "nuke:" .. k2,
				label = UIRules.SHORT[k2],
				icon = k2,
				ok = ok2,
				reason = if not av2.ok then tostring(av2.reason) else tostring(pl2.reason),
				danger = true,
				cost = av2.cost,
				-- atom bombs stack (x2 against a SAM): a bulk launch
				sub = if ok2 and k2 == "atom" then self:bulk_ring("nuke", k2) else nil,
			})
		end
		local only_strikes = self:struct_count(Defs.S_SILO) == 0
		table.insert(items, {
			id = "nuke",
			label = if only_strikes then "Raid" else "Warhead",
			icon = if only_strikes then launch_kinds[1] else "atom",
			ok = true,
			reason = "",
			danger = true,
			sub = nsub,
		})
	end

	if playing and own ~= 0 and own ~= me then
		local target_info = s:get_owner(own)
		if s:are_allies(me, own) then
			local plan = self:donate_plan(own)
			table.insert(items, {
				id = "donate",
				label = "Aid",
				icon = "donate",
				ok = plan.want >= 1 and not plan.full,
				reason = if plan.want < 1 then "You have none to spare" elseif plan.full then "Their ranks are full" else "",
				danger = false,
				troops = plan.amount,
				capped = plan.capped,
			})
			-- the last ALLIANCE_EXTEND_WINDOW_TICKS: ask to renew (renewed once both asked)
			local ai = s:alliance_info(me, own)
			if ai ~= nil and ai.in_window then
				table.insert(items, {
					id = "ally_extend",
					label = "Keep the pact",
					icon = "alliance",
					ok = ai.can_extend,
					reason = if ai.me_asked then "You have asked" else "",
					danger = false,
				})
			end
			-- (a teammate is no alliance: nothing to betray)
			if s:has_alliance(me, own) then
				table.insert(
					items,
					{ id = "ally_break", label = "Break your oath", icon = "betray", ok = true, reason = "", danger = true }
				)
			end
		elseif s:has_request(own, me) then
			table.insert(
				items,
				{ id = "ally_accept", label = "Seal", icon = "alliance", ok = true, reason = "", danger = false }
			)
		elseif s:has_request(me, own) then
			table.insert(items, {
				id = "ally_request",
				label = "Pact",
				icon = "alliance",
				ok = false,
				reason = "Offer sent",
				danger = false,
			})
		elseif target_info ~= nil and target_info.alive then
			-- a new request waits 30 s after the previous one (Rules.ALLY_REQUEST_COOLDOWN_TICKS)
			local wait = s:request_cooldown_left(me, own)
			table.insert(items, {
				id = "ally_request",
				label = "Pact",
				icon = "alliance",
				ok = wait <= 0,
				reason = if wait > 0 then string.format("In %ds", math.ceil(wait / Defs.TICK_RATE)) else "",
				danger = false,
			})
		end
	end

	return items
end

return UIRules
