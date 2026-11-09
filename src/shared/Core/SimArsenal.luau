--!native
-- The War College's weapons (2026-10-04, reworked 2026-11-02): units and warheads a ruler earns with Renown or buys with
-- Robux. A mixin of the flattened Sim class, after SimNukes. What a player may use is a bit mask per owner (Sim.o_unlock,
-- Defs.UNLOCK; the match's host sets it from the player's saved unlocks with Sim.set_unlocks): without the bit the Sim
-- refuses the build, the launch or the call. The AI builds none of it.
--
--   Long Guns (structure)   answers only a nation at war with its owner; a shell breaks up that nation's march on them
--   Aerodrome (structure)    flies a Sky Raid at a tile within reach, then rearms: it grounds Flak and Launch Sites
--   Lance Cannon (structure) fires a shot along a line, through every enemy building near its last stretch, then reloads
--   Sunbreaker (silo)       burns a wide disc: buildings, ships and a share of each army, but no land (SimNukes._sunbreak)
--   Shatter Line (silo)     a small burst, and a straight line of shards across the aim
--   Harvest Levy (call)     gold for 30 % of the troop cap, and no regrowth for a while
-- and one call that is everyone's, not the War College's:
--   Call to Arms (call)     from the Conflict, gold for a quarter of the cap at a price per troop that rises each call
--   Drilled Crews           reloads after a shot run faster, buildings go up sooner
--
-- Shells, raids and Lance Shots are munitions like the warheads (SimNukes: the same list, the same NUKE / BOOM events, a
-- straight flight path), but they land as a strike (_strike): they take no land and leave no poisoned ground, and never hurt
-- their owner's or an ally's. Structures have health only for the Lance Shot (Rules.STRUCT_HP): at 0 one loses a level and
-- is whole again, or is destroyed at level 1.

local Defs = require("./Defs")
local Ev = require("./Ev")
local Rules = require("./Rules")
local SimState = require("./SimState")

local readi32 = buffer.readi32
local readu8 = buffer.readu8

local filled = SimState.filled
local a_an = SimState.a_an
local MAXO = Defs.MAX_OWNERS
local STRUCT_KINDS = SimState.STRUCT_KINDS

local S_SAM = Defs.S_SAM
local S_SILO = Defs.S_SILO
local U_TRANSPORT = Defs.U_TRANSPORT
local N_WARHEAD = Defs.N_WARHEAD
local N_SCATTER = Defs.N_SCATTER
local N_SHELL = Defs.N_SHELL
local N_AIRSTRIKE = Defs.N_AIRSTRIKE
local N_SLUG = Defs.N_SLUG
local UNLOCK = Defs.UNLOCK

local SimArsenal = {}

--- What a locked build / launch / call tells the player (the client offers the unlock itself).
SimArsenal.LOCKED_TEXT = "The War College hasn't taught you %s"

function SimArsenal.install(C)
	function C:_init_arsenal()
		--- Defs.UNLOCK bits per owner.
		self.o_unlock = filled(MAXO, 0)
		--- Tick of each owner's last Harvest Levy, and the tick their fields fill again (no regrowth until then).
		self.o_reinforce_tick = filled(MAXO, -100000)
		self.o_levy_until = filled(MAXO, 0)
		--- Calls to Arms each owner has made this match (the price per troop rises with each), and the tick of its last.
		self.o_call_n = filled(MAXO, 0)
		self.o_call_tick = filled(MAXO, -100000)
		--- Finished batteries, in the order they finished.
		self.batteries = {} :: { any }
	end

	--- The Arsenal unlocks `id` plays with (a Defs.UNLOCK bit mask), from now on.
	function C:set_unlocks(id: number, mask: number)
		if id > 0 and id < MAXO and type(mask) == "number" and mask == mask then
			self.o_unlock[id] = bit32.band(math.max(0, math.floor(mask)), Defs.UNLOCK_ALL)
		end
	end

	function C:has_unlock(id: number, bit: number): boolean
		return bit == 0 or bit32.band(self.o_unlock[id] or 0, bit) ~= 0
	end

	--- Neither `a`'s own nor an ally's: what a strike may hurt.
	function C:_strike_enemy(a: number, b: number): boolean
		return b > 0 and b ~= a and not self:allied(a, b)
	end

	--- Salvage Crews: `owner` lost building `s` to an enemy, and SALVAGE_SHARE of the gold paid into it (every level)
	--- comes back, once: a building passed back and forth pays nothing again (audit D5, 2026-11-06: it refunded the next
	--- building's price on every capture and could be farmed). (Called where a loss to an enemy is told: a building
	--- pulled down by its owner pays nothing.)
	function C:_salvage(owner: number, s: any)
		local paid = tonumber(s.paid) or 0
		-- (whoever holds it now paid nothing for it)
		s.paid = 0
		if owner <= 0 or bit32.band(self.o_unlock[owner] or 0, UNLOCK.reload2x) == 0 then
			return
		end
		local gold = math.floor(paid * Rules.SALVAGE_SHARE)
		if gold <= 0 then
			return
		end
		self.o_gold[owner] += gold
		-- (a Warhead takes a dozen at once: one line)
		self._salvage_said = self._salvage_said or {}
		if self.tick >= (self._salvage_said[owner] or 0) then
			self._salvage_said[owner] = self.tick + Rules.SALVAGE_SAY_TICKS
			self:msg(owner, Defs.MSG_GOOD, string.format("Salvage Crews bring back %s gold", Defs.format_troops(gold)))
		end
	end

	-- =========================================================================================
	-- Structure health
	-- =========================================================================================

	--- `dmg` to structure `s` from owner `by`: at 0 health it loses a level (and is whole again) or,
	--- at level 1, is destroyed.
	function C:damage_struct(s: any, dmg: number, by: number)
		if s.dead or dmg <= 0 then
			return
		end
		local full = Rules.STRUCT_HP[s.kind] or 1000
		s.hp = (s.hp or full) - dmg
		if s.hp > 0 then
			return
		end
		local owner = s.owner
		local title = Defs.STRUCT_TITLES[s.kind]
		if s.level <= 1 then
			self:destroy_struct(s)
			self:_salvage(owner, s)
			self:msg(owner, Defs.MSG_BAD, string.format("Your %s lies in ruin. %s's doing.", title, self:name_of(by)))
			return
		end
		s.level -= 1
		s.hp = full
		local b = owner * STRUCT_KINDS + s.kind
		self.o_slevel[b] -= 1
		if s.active then
			self.o_alevel[b] -= 1
		end
		self:ev({ Ev.STRUCT_LEVEL, s.sid, s.level, s.active_tick })
		-- a SAM or silo loses a missile slot: one still reloading goes first
		if (s.kind == S_SAM or s.kind == S_SILO) and #s.shots > s.level then
			while #s.shots > s.level do
				table.remove(s.shots)
			end
			self:ev({ Ev.STRUCT_SHOTS, s.sid, table.clone(s.shots) })
		end
		self:msg(
			owner,
			Defs.MSG_BAD,
			string.format("%s's shot: your %s drops to rank %d", self:name_of(by), title, s.level)
		)
	end

	-- =========================================================================================
	-- Artillery
	-- =========================================================================================

	--- A finished battery starts its first gap (SimStructures._activate).
	function C:_battery_ready(s: any)
		s.next_fire = self.tick + self:_battery_gap(s)
		table.insert(self.batteries, s)
	end

	function C:_battery_gap(s: any): number
		return self.rng:randi_range(Rules.ARTILLERY_GAP_MIN, Rules.ARTILLERY_GAP_MAX)
	end

	--- Where battery `s` aims: land within range of a nation at war with its owner (marching on them, or being marched
	--- on by them), found by a few random looks over its range. -1: nothing.
	function C:_battery_target(s: any): number
		local id = s.owner
		local at_war = {} :: { [number]: boolean }
		local any = false
		for _, a in self.attacks do
			if a.dead then
				continue
			end
			local foe = if a.target == id then a.attacker elseif a.attacker == id then a.target else 0
			if foe > 0 and self:_strike_enemy(id, foe) then
				at_war[foe] = true
				any = true
			end
		end
		if not any then
			return -1
		end
		local range = self.R.artillery_range()
		local W, H = self.W, self.H
		local cx, cy = s.tile % W, s.tile // W
		local owner = self.owner
		local land = self.land
		local rng = self.rng
		for _ = 1, Rules.ARTILLERY_SAMPLES do
			local ang = rng:randf() * 2.0 * math.pi
			local rad = range * math.sqrt(rng:randf())
			local x = math.floor(cx + math.cos(ang) * rad + 0.5)
			local y = math.floor(cy + math.sin(ang) * rad + 0.5)
			if x < 0 or y < 0 or x >= W or y >= H then
				continue
			end
			local t = y * W + x
			if readu8(land, t) == 1 and at_war[readi32(owner, t * 4)] then
				return t
			end
		end
		return -1
	end

	--- Batteries whose gap is over fire a shell (or look again in a moment).
	function C:arsenal_tick()
		local list = self.batteries
		local n = #list
		if n == 0 then
			return
		end
		local tick = self.tick
		local R = self.R
		local w = 0
		for i = 1, n do
			local s = list[i]
			if s.dead then
				continue
			end
			w += 1
			list[w] = s
			if tick < s.next_fire then
				continue
			end
			local t = self:_battery_target(s)
			if t < 0 then
				s.next_fire = tick + Rules.ARTILLERY_IDLE_TICKS
				continue
			end
			s.next_fire = tick + self:_battery_gap(s)
			local arc = R.munition_arc(self.W, self.H, s.tile, t, N_SHELL)
			self:_spawn_nuke(N_SHELL, s.owner, s.tile, t, R.nuke_arc_ticks(arc, N_SHELL), arc)
		end
		for i = n, w + 1, -1 do
			list[i] = nil
		end
	end

	-- =========================================================================================
	-- Strikes (a shell, a raid or a Lance Shot lands)
	-- =========================================================================================

	--- A shell lands on `o`'s land: 7 % of every force `o` has marching on the shooter, or, with none, a small share of `o`'s
	--- army at home.
	function C:_shell_hits(o: number, shooter: number)
		local dbg_flow = self.dbg_flow
		local march = false
		for _, a in self.attacks do
			if not a.dead and a.attacker == o and a.target == shooter then
				local kill = a.troops * Rules.SHELL_MARCH_FRAC
				a.troops -= kill
				dbg_flow[o * 5 + 3] += kill
				march = true
			end
		end
		if not march then
			local kill = Rules.strike_kill(N_SHELL, self.o_troops[o], 1)
			self.o_troops[o] -= kill
			dbg_flow[o * 5 + 3] += kill
		end
	end

	--- Empties an enemy Flak Battery or Launch Site: every slot reloads, and none is ready for RAID_GROUNDED_TICKS.
	function C:_ground_launcher(s: any, by: number)
		local ready_at = self.tick + Rules.RAID_GROUNDED_TICKS - (Rules.RELOAD_TICKS[s.kind] or 0)
		local shots = table.create(s.level, ready_at)
		s.shots = shots
		self:ev({ Ev.STRUCT_SHOTS, s.sid, table.clone(shots) })
		self:msg(
			s.owner,
			Defs.MSG_BAD,
			string.format("%s's raid grounded your %s", self:name_of(by), Defs.STRUCT_TITLES[s.kind])
		)
	end

	--- A Lance Shot's line: every enemy building within LANCE_WIDTH of the last LANCE_LINE tiles of its flight takes the
	--- shot's damage, in the order they were built (so a replay is the same).
	function C:_lance_line(n: any)
		local R = self.R
		local W = self.W
		local tx, ty = n.to_tile % W, n.to_tile // W
		local fx, fy = n.from_tile % W, n.from_tile // W
		local dx, dy = fx - tx, fy - ty
		local len = math.sqrt(dx * dx + dy * dy)
		if len <= 0 then
			return
		end
		local ux, uy = dx / len, dy / len
		local reach = math.min(len, Rules.LANCE_LINE_FULL / R.K_LIN)
		local width = Rules.LANCE_WIDTH_FULL / R.K_LIN
		local shooter = n.owner
		local dmg = Rules.STRIKE_DAMAGE[n.kind] or 0
		local hit = {}
		for _, s in self.struct_list do
			if not s.dead and self:_strike_enemy(shooter, s.owner) then
				local sx, sy = s.tile % W - tx, s.tile // W - ty
				local along = sx * ux + sy * uy
				local off = sx * uy - sy * ux
				if along >= -width and along <= reach and math.abs(off) <= width then
					table.insert(hit, s)
				end
			end
		end
		for _, s in hit do
			self:damage_struct(s, dmg, shooter)
		end
	end

	function C:_strike(n: any)
		local kind = n.kind
		local to = n.to_tile
		local shooter = n.owner
		local R = self.R
		local range_d2 = self.range_d2
		local _, radius = R.nuke_radii(kind)
		local owner = self.owner
		if kind == N_SHELL then
			local o = readi32(owner, to * 4)
			if self:_strike_enemy(shooter, o) then
				self:_shell_hits(o, shooter)
			end
		elseif kind == N_SLUG then
			self:_lance_line(n)
		else
			-- a raid: land under the bombs, per army that isn't the shooter's or an ally's
			local hit: { [number]: number } = {}
			local order = {}
			for _, t in self:disk_tiles(to, radius, true) do
				local o = readi32(owner, t * 4)
				if self:_strike_enemy(shooter, o) then
					if hit[o] == nil then
						hit[o] = 0
						table.insert(order, o)
					end
					hit[o] += 1
				end
			end
			local o_troops = self.o_troops
			local dbg_flow = self.dbg_flow
			local tick = self.tick
			for _, o in order do
				local troops = o_troops[o]
				local kill = Rules.strike_kill(kind, troops, hit[o] * R.K_AREA)
				if kill <= 0 then
					continue
				end
				local keep = 1.0 - kill / math.max(troops, 1.0)
				dbg_flow[o * 5 + 3] += kill
				o_troops[o] = troops - kill
				-- the same share of its armies in the field and at sea
				for _, a in self.attacks do
					if not a.dead and a.attacker == o then
						a.troops *= keep
					end
				end
				for _, u in self.unit_list do
					if not u.dead and u.owner == o and u.kind == U_TRANSPORT then
						u.troops *= keep
					end
				end
				self:add_grudge(o, shooter, Rules.HOSTILE_TICKS)
				self.o_attacked_tick[o] = tick
			end
			local r2 = radius * radius
			local r = math.max(1, math.ceil(radius))
			for _, s in self:structs_in_box(to, math.max(1, self.geo_span(to, radius)), r) do
				if
					not s.dead
					and (s.kind == S_SAM or s.kind == S_SILO)
					and self:_strike_enemy(shooter, s.owner)
					and range_d2(to, s.tile) <= r2
				then
					self:_ground_launcher(s, shooter)
				end
			end
		end
		self:ev({ Ev.BOOM, n.uid, kind, to, math.max(1, math.ceil(radius)), shooter })
		local victim = readi32(owner, to * 4)
		if kind ~= N_SHELL and self:_strike_enemy(shooter, victim) then
			self:msg(
				victim,
				Defs.MSG_BAD,
				string.format(
					"On your land: %s, from %s",
					SimState.cap_first(a_an(Defs.NUKE_TITLES[kind])),
					self.o_name[shooter]
				)
			)
		end
	end

	-- =========================================================================================
	-- Shatter Line
	-- =========================================================================================

	--- The shards that leave the silo with a Shatter Line aimed at `aim`: three a side, in a straight line square to the
	--- flight, SCATTER_STEP tiles apart, never onto `id`'s or an ally's land. The ones nearest the aim land first.
	function C:_scatter_warheads(id: number, from_tile: number, aim: number, flight: number)
		local R = self.R
		local W, H = self.W, self.H
		local ax, ay = aim % W, aim // W
		local dx, dy = ax - from_tile % W, ay - from_tile // W
		local len = math.sqrt(dx * dx + dy * dy)
		local px, py = if len > 0 then -dy / len else 0.0, if len > 0 then dx / len else 1.0
		local step = Rules.SCATTER_STEP_FULL / R.K_LIN
		local owner = self.owner
		local fired = 0
		for ring = 1, Rules.SCATTER_MAX // 2 do
			for _, side in { 1, -1 } do
				local x = math.floor(ax + px * step * ring * side + 0.5)
				local y = math.floor(ay + py * step * ring * side + 0.5)
				if x < 0 or y < 0 or x >= W or y >= H then
					continue
				end
				local c = y * W + x
				local o = readi32(owner, c * 4)
				if o == id or (o ~= 0 and self:allied(id, o)) then
					continue
				end
				fired += 1
				local arc = R.nuke_arc(W, H, from_tile, c)
				local wn = self:_spawn_nuke(
					N_WARHEAD,
					id,
					from_tile,
					c,
					math.max(flight, R.nuke_arc_ticks(arc, N_SCATTER)) + fired * 2,
					arc
				)
				wn.target_owner = o
			end
		end
	end

	-- =========================================================================================
	-- Harvest Levy
	-- =========================================================================================

	--- Ticks until `id` may call a Harvest Levy again (0: now).
	function C:reinforce_wait(id: number): number
		return math.max(0, self.o_reinforce_tick[id] + Rules.REINFORCE_COOLDOWN_TICKS - self.tick)
	end

	--- The Harvest Levy's intent: Rules.REINFORCE_COST gold for 30 % of the troop cap, never past it, and no regrowth for a while.
	function C:reinforce(id: number): boolean
		if not self:has_unlock(id, UNLOCK.reinforce) then
			self:msg(id, Defs.MSG_INFO, string.format(SimArsenal.LOCKED_TEXT, "the Harvest Levy"))
			return false
		end
		local wait = self:reinforce_wait(id)
		if wait > 0 then
			self:msg(
				id,
				Defs.MSG_INFO,
				string.format("The fields need %d s more", math.ceil(wait / Rules.TICK_RATE))
			)
			return false
		end
		local troops = Rules.reinforce_troops(self.o_troops[id], self.o_cap[id])
		if troops <= 0 then
			self:msg(id, Defs.MSG_INFO, "Your ranks are already full")
			return false
		end
		if self.o_gold[id] < Rules.REINFORCE_COST then
			self:msg(id, Defs.MSG_INFO, "The Harvest Levy costs more gold than you hold")
			return false
		end
		self.o_gold[id] -= Rules.REINFORCE_COST
		self.o_troops[id] += troops
		self.o_reinforce_tick[id] = self.tick
		self.o_levy_until[id] = self.tick + Rules.LEVY_EMPTY_TICKS
		self:ev({ Ev.REINFORCE, id, troops, self.tick + Rules.REINFORCE_COOLDOWN_TICKS })
		self._force_stats = true
		return true
	end

	-- =========================================================================================
	-- Call to Arms (everyone's: the late war's gold sink, audit 2026-11-06 #6)
	-- =========================================================================================

	--- Whether the Call to Arms is open in this match now (from the Conflict; Rules.call_open).
	function C:call_open(): boolean
		if self.phase ~= Defs.PHASE_PLAYING or (self.playing_since or -1) < 0 then
			return false
		end
		return Rules.call_open(self.tick - self.playing_since, if self.doctrines_on then self.eras else nil)
	end

	--- Ticks until `id` may call to arms again (0: now).
	function C:call_wait(id: number): number
		return math.max(0, self.o_call_tick[id] + Rules.CALL_TO_ARMS_COOLDOWN_TICKS - self.tick)
	end

	--- Gold `id`'s next Call to Arms costs now (0 when it would bring no troops).
	function C:call_cost(id: number): number
		return Rules.call_cost(self.o_call_n[id], self.o_troops[id], self.o_cap[id])
	end

	--- The Call to Arms' intent: a quarter of the troop cap, never past it, for Rules.call_cost gold; once a minute.
	function C:call_to_arms(id: number): boolean
		if id <= 0 or self.o_alive[id] == 0 or self.o_spawned[id] == 0 or self.o_kind[id] == Defs.KIND_TRIBE then
			return false
		end
		if not self:call_open() then
			self:msg(id, Defs.MSG_INFO, "The Call to Arms opens in the Conflict")
			return false
		end
		local wait = self:call_wait(id)
		if wait > 0 then
			self:msg(id, Defs.MSG_INFO, string.format("The next Call to Arms in %d s", math.ceil(wait / Rules.TICK_RATE)))
			return false
		end
		local troops = Rules.call_troops(self.o_troops[id], self.o_cap[id])
		if troops <= 0 then
			self:msg(id, Defs.MSG_INFO, "Your ranks are already full")
			return false
		end
		local cost = self:call_cost(id)
		if self.o_gold[id] < cost then
			self:msg(id, Defs.MSG_INFO, "The Call to Arms costs more gold than you hold")
			return false
		end
		self.o_gold[id] -= cost
		self.o_troops[id] += troops
		self.o_call_n[id] += 1
		self.o_call_tick[id] = self.tick
		self:ev({ Ev.CALL_TO_ARMS, id, troops, self.tick + Rules.CALL_TO_ARMS_COOLDOWN_TICKS, self.o_call_n[id] })
		self._force_stats = true
		return true
	end

	--- Snapshot rows of the calls made: { id, calls, ready_tick } (nil when nobody has called).
	function C:_call_rows(): { { number } }?
		local rows = nil
		for id = 1, self.owner_total do
			if self.o_call_n[id] > 0 then
				rows = rows or {}
				table.insert(rows, { id, self.o_call_n[id], self.o_call_tick[id] + Rules.CALL_TO_ARMS_COOLDOWN_TICKS })
			end
		end
		return rows
	end
end

return SimArsenal
