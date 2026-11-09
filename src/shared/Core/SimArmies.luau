--!nonstrict
-- Depth Phase 5 (docs/DEPTH_DESIGN.md): armies. An army is troops raised out of the realm's pool with a general
-- (skill 1-5); it costs gold and food while raised, and disbanding sends its troops home.
--
-- Today's maps fight on **fronts**: an army is set against one realm with a stance. Attack keeps an attack running along
-- that border with the army's troops (it refills from home as it goes); advance attacks only at full strength; hold
-- attacks nothing, and that realm's attacks on you cost it more by the army's strength. Its general's skill makes the
-- attacks it feeds cheaper.
-- The medieval start dates fight with **levies**: an army marches over land to a tile; meeting an enemy army near, a
-- battle is fought (troops, general, terrain, a fort); the loser loses most of its men and goes home. Reaching an
-- enemy province it lays a siege (longer with a fort, shorter with siege skill); when the siege ends the province passes
-- whole. A siege also feeds an attack on the province's land around it, tile by tile.
--
-- `armies[aid] = { aid, owner, troops, size, general, mode ("front" / "march"), stance, target (owner), dest (tile),
-- tile, state ("idle", "march", "siege", "home"), siege_p, siege_left }`.
local Defs = require("./Defs")
local Ev = require("./Ev")

local SimArmies = {}

local TICK_RATE = Defs.TICK_RATE
local readi32 = buffer.readi32
local readu8 = buffer.readu8

SimArmies.STANCES = { attack = true, advance = true, hold = true }
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

function SimArmies.install(C: any)
	function C:_init_armies()
		if self.depth == nil then
			return
		end
		self.armies = {}
		self._army_next = 1
		self._army_dirty = {}
		--- medieval start dates march; today's fight on fronts
		self.army_mode = if self.period ~= nil then "march" else "front"
	end

	local function general_of(self: any, id: number): number
		return math.clamp(1 + self.rng:randi_range(0, 2) + math.floor(self:lev(id, "general")), 1, 5)
	end

	local function dirty(self: any, ar: any)
		self._army_dirty[ar.aid] = true
	end

	--- The armies of `id`, by aid.
	function C:armies_of(id: number): { any }
		local out = {}
		if self.armies == nil then
			return out
		end
		for _, k in self:_ordered_keys(self.armies) do
			local ar = self.armies[k]
			if ar.owner == id then
				table.insert(out, ar)
			end
		end
		return out
	end

	--- Raises an army of `troops` (at most army_max_share of what is at home) at `id`'s capital. Its aid, or 0.
	function C:raise_army(id: number, troops: number): number
		if self.armies == nil or self.o_alive[id] == 0 or self.o_kind[id] == Defs.KIND_TRIBE then
			return 0
		end
		if #self:armies_of(id) >= self.dp.army_max_count then
			self:msg(id, Defs.MSG_INFO, "You have as many armies as you can lead")
			return 0
		end
		local take = math.floor(math.min(troops, self.o_troops[id] * self.dp.army_max_share))
		if take < self.dp.army_min then
			self:msg(id, Defs.MSG_INFO, "Too few troops at home to raise an army")
			return 0
		end
		self.o_troops[id] -= take
		local aid = self._army_next
		self._army_next += 1
		local home = self.o_spawn_tile[id]
		local ar = {
			aid = aid,
			owner = id,
			troops = take,
			size = take,
			general = general_of(self, id),
			mode = self.army_mode,
			stance = "hold",
			target = 0,
			dest = -1,
			tile = home,
			state = "idle",
			siege_p = 0,
			siege_left = 0,
			stuck = 0,
		}
		self.armies[aid] = ar
		dirty(self, ar)
		return aid
	end

	--- Disbands army `aid` of `id`: its troops go home.
	function C:disband_army(id: number, aid: number): boolean
		local ar = self.armies and self.armies[aid]
		if ar == nil or ar.owner ~= id then
			return false
		end
		self.o_troops[id] += math.floor(ar.troops)
		self.armies[aid] = nil
		self._army_dirty[aid] = true
		return true
	end

	--- A front order (today's maps): army `aid` of `id` against realm `target` with `stance`.
	function C:army_front(id: number, aid: number, target: number, stance: string): boolean
		local ar = self.armies and self.armies[aid]
		if ar == nil or ar.owner ~= id or not SimArmies.STANCES[stance] or target <= 0 or target > self.owner_total then
			return false
		end
		if target == id or self.o_alive[target] == 0 then
			return false
		end
		if stance ~= "hold" and not self:may_attack(id, target) then
			return false
		end
		ar.target = target
		ar.stance = stance
		ar.state = "idle"
		dirty(self, ar)
		return true
	end

	--- A march order (medieval): army `aid` of `id` to tile `t` (land).
	function C:army_march(id: number, aid: number, t: number): boolean
		local ar = self.armies and self.armies[aid]
		if ar == nil or ar.owner ~= id or t < 0 or t >= self.N or readu8(self.land, t) == 0 then
			return false
		end
		ar.dest = t
		ar.state = "march"
		ar.stuck = 0
		local tg = readi32(self.owner, t * 4)
		if tg ~= 0 and tg ~= id and self.o_kind[tg] ~= Defs.KIND_TRIBE and not self:at_war(id, tg) then
			if not self:may_attack(id, tg) then
				ar.state = "idle"
				return false
			end
		end
		dirty(self, ar)
		return true
	end

	--- Food the armies of `id` eat a second (SimEconomy).
	local prev_food = C._army_food
	function C:_army_food(id: number): number
		local f = prev_food(self, id)
		if self.armies == nil then
			return f
		end
		for _, ar in self.armies do
			if ar.owner == id then
				-- (on campaign it eats a soldier's rations; waiting at home, a villager's)
				local away = ar.state == "march" or ar.state == "siege" or (ar.mode == "front" and ar.target ~= 0 and ar.stance ~= "hold")
				f += ar.troops * (if away then self.dp.food_war else self.dp.food_home)
			end
		end
		return f
	end

	--- What attacks of `at` on `tg` lose on top: `tg`'s armies holding against `at`, by their strength.
	local prev_pair = C._pair_loss_mult
	function C:_pair_loss_mult(at: number, tg: number): number
		local m = prev_pair(self, at, tg)
		if self.armies == nil then
			return m
		end
		local held = 0
		for _, ar in self.armies do
			if ar.owner == tg and ar.target == at and ar.stance == "hold" then
				held += ar.troops
			end
		end
		if held > 0 then
			local marching = math.max(self:troops_in_attacks(at), 1)
			m *= 1.0 + self.dp.hold_k * math.min(held / marching, 1.0)
		end
		return m
	end

	--- An attack an army feeds: its general makes it cheaper (read by the attack loop through a.general).
	local function feed(self: any, ar: any, troops: number): boolean
		local a = self:start_attack(ar.owner, ar.target, troops, -1)
		if a == nil then
			return false
		end
		a.general = math.max(a.general or 0, ar.general)
		return true
	end

	local function step_toward(self: any, ar: any): boolean
		local W = self.W
		local t = ar.tile
		local tx, ty = t % W, t // W
		local dx, dy = ar.dest % W, ar.dest // W
		local best, bd = -1, (tx - dx) ^ 2 + (ty - dy) ^ 2
		for _, d in DIRS do
			local x, y = tx + d[1], ty + d[2]
			if x >= 0 and y >= 0 and x < W and y < self.H then
				local c = y * W + x
				if self:claimable(c) then
					local dd = (x - dx) ^ 2 + (y - dy) ^ 2
					if dd < bd then
						best, bd = c, dd
					end
				end
			end
		end
		if best < 0 then
			return false
		end
		ar.tile = best
		return true
	end

	--- A battle between two armies at war: the stronger by troops x general x ground wins; the loser loses most of its
	--- men and goes home.
	function C:_battle(x: any, y: any)
		local dp = self.dp
		local function power(ar: any, defending: boolean): number
			local p = ar.troops * (1 + dp.general_k * ar.general)
			if defending then
				local tt = readu8(self.terr, ar.tile)
				if tt == Defs.T_MOUNTAIN then
					p *= dp.battle_mountain
				elseif tt == Defs.T_HIGHLAND then
					p *= dp.battle_hills
				end
				local pv = self:province_at(ar.tile)
				if pv > 0 then
					p *= 1 + dp.battle_fort * math.min(self:fort_level(pv, ar.owner), dp.fort_max)
				end
			end
			return p
		end
		-- the one on its own land defends
		local x_home = readi32(self.owner, x.tile * 4) == x.owner
		local px, py = power(x, x_home), power(y, not x_home)
		local win, lose, pw, pl = x, y, px, py
		if py > px then
			win, lose, pw, pl = y, x, py, px
		end
		local w_loss = math.floor(win.troops * dp.battle_win_loss * math.min(pl / math.max(pw, 1), 1))
		local l_loss = math.floor(lose.troops * dp.battle_lose_loss)
		win.troops -= w_loss
		lose.troops -= l_loss
		self.dbg_flow[win.owner * 5 + 3] += w_loss
		self.dbg_flow[lose.owner * 5 + 3] += l_loss
		lose.state = "home"
		lose.dest = self.o_spawn_tile[lose.owner]
		self:add_prestige(win.owner, dp.prestige_battle)
		self:ev({ Ev.BATTLE, win.tile, win.owner, lose.owner, w_loss, l_loss })
		local where = self.P.name[self:province_at(win.tile)] or "the field"
		self:msg(win.owner, Defs.MSG_GOOD, string.format("Victory at %s over %s", where, self.o_name[lose.owner]))
		self:msg(lose.owner, Defs.MSG_BAD, string.format("Defeat at %s against %s", where, self.o_name[win.owner]))
		dirty(self, win)
		dirty(self, lose)
	end

	--- A siege's length in seconds for province `p` held by `defender`, by army `ar`.
	function C:siege_seconds(p: number, defender: number, ar: any): number
		local dp = self.dp
		local fort = math.min(self:fort_level(p, defender), dp.fort_max)
		local s = dp.siege_base_s * (1 + dp.siege_fort * fort) * (1 + dp.siege_dev * self.P.dev[p])
		s /= math.max(1 + self:lev(ar.owner, "siege") + dp.siege_general * ar.general, 0.2)
		return math.max(math.floor(s), 5)
	end

	--- Once a second: upkeep, refills, fronts, marches, battles, sieges.
	function C:_armies_second()
		local armies = self.armies
		if armies == nil or next(armies) == nil then
			return
		end
		local dp = self.dp
		local list = {}
		for _, k in self:_ordered_keys(armies) do
			table.insert(list, armies[k])
		end
		for _, ar in list do
			local id = ar.owner
			if self.o_alive[id] == 0 then
				armies[ar.aid] = nil
				self._army_dirty[ar.aid] = true
				continue
			end
			-- upkeep: gold a second for its men; unpaid, it melts away
			local cost = ar.troops * dp.army_upkeep
			if self.o_gold[id] >= cost then
				self.o_gold[id] -= cost
			else
				ar.troops *= 0.98
				dirty(self, ar)
			end
			if ar.troops < dp.army_min * 0.25 then
				self.o_troops[id] += math.floor(ar.troops)
				armies[ar.aid] = nil
				self._army_dirty[ar.aid] = true
				continue
			end
			if ar.mode == "front" then
				self:_front_second(ar)
			else
				self:_march_second(ar)
			end
		end
		-- battles: marching armies of realms at war, within reach of each other
		local reach2 = dp.battle_reach * dp.battle_reach
		local W = self.W
		for i = 1, #list do
			local x = list[i]
			if armies[x.aid] == nil or x.mode ~= "march" then
				continue
			end
			for j = i + 1, #list do
				local y = list[j]
				if armies[y.aid] ~= nil and y.mode == "march" and x.owner ~= y.owner and self:at_war(x.owner, y.owner) then
					local dx, dy = x.tile % W - y.tile % W, x.tile // W - y.tile // W
					if dx * dx + dy * dy <= reach2 and x.state ~= "home" and y.state ~= "home" then
						self:_battle(x, y)
					end
				end
			end
		end
	end

	function C:_front_second(ar: any)
		local dp = self.dp
		local id = ar.owner
		-- refill toward its size from home
		if ar.troops < ar.size then
			local add = math.min(ar.size - ar.troops, ar.size * dp.army_refill, self.o_troops[id] * 0.5)
			if add > 0 then
				ar.troops += add
				self.o_troops[id] -= add
				dirty(self, ar)
			end
		end
		local tg = ar.target
		if tg == 0 or ar.stance == "hold" then
			return
		end
		if self.o_alive[tg] == 0 or not self:at_war(id, tg) then
			-- the war is over: it stands down
			ar.stance = "hold"
			ar.target = 0
			dirty(self, ar)
			return
		end
		local ready = if ar.stance == "advance" then ar.troops >= ar.size * 0.9 else ar.troops >= ar.size * 0.3
		if ready then
			local send = math.floor(ar.troops * dp.front_send)
			if send >= 1 and feed(self, ar, send) then
				ar.troops -= send
				dirty(self, ar)
			end
		end
	end

	function C:_march_second(ar: any)
		local dp = self.dp
		local id = ar.owner
		if ar.state == "siege" then
			local p = ar.siege_p
			local defender = ar.siege_owner or self.p_holder[p]
			if defender == id or defender == 0 or self.o_alive[defender] == 0 then
				ar.state = "idle"
				dirty(self, ar)
				return
			end
			ar.siege_left -= 1
			ar.troops *= 1 - dp.siege_attrition
			-- the land around falls to an attack the siege feeds
			if (self.tick // TICK_RATE) % 5 == 0 and self:at_war(id, defender) then
				ar.target = defender
				local send = math.floor(ar.troops * dp.siege_send)
				if send >= 1 and feed(self, ar, send) then
					ar.troops -= send
				end
			end
			if ar.siege_left <= 0 then
				self:handover(p, defender, id)
				self:add_prestige(id, dp.prestige_siege)
				self:ev({ Ev.SIEGE, p, id, defender })
				self:msg(id, Defs.MSG_GOOD, string.format("%s falls to your siege", self.P.name[p]))
				self:msg(defender, Defs.MSG_BAD, string.format("%s falls to %s", self.P.name[p], self.o_name[id]))
				ar.state = "idle"
			end
			dirty(self, ar)
			return
		end
		if ar.state ~= "march" and ar.state ~= "home" then
			return
		end
		if ar.dest < 0 then
			ar.state = "idle"
			return
		end
		for _ = 1, dp.march_tiles do
			if ar.tile == ar.dest then
				break
			end
			if not step_toward(self, ar) then
				ar.stuck += 1
				break
			end
		end
		dirty(self, ar)
		local W = self.W
		local near = math.abs(ar.tile % W - ar.dest % W) <= 1 and math.abs(ar.tile // W - ar.dest // W) <= 1
		if ar.stuck > 3 then
			ar.state = "idle"
			self:msg(id, Defs.MSG_INFO, "Your army can find no road there")
			return
		end
		if near or ar.tile == ar.dest then
			if ar.state == "home" then
				-- home again: it waits, ready for orders
				ar.state = "idle"
				return
			end
			local p = self:province_at(ar.dest)
			local defender = if p > 0 then self.p_holder[p] else 0
			if defender == 0 and p > 0 then
				-- (nobody holds it whole: whoever owns the ground the army stands before)
				defender = readi32(self.owner, ar.dest * 4)
			end
			if p > 0 and defender ~= 0 and defender ~= id and self:at_war(id, defender) then
				ar.siege_owner = defender
				ar.state = "siege"
				ar.siege_p = p
				ar.siege_left = self:siege_seconds(p, defender, ar)
				self:msg(defender, Defs.MSG_BAD, string.format("%s lays siege to %s", self.o_name[id], self.P.name[p]))
			else
				ar.state = "idle"
			end
		end
	end

	--- The attack loop's general: an attack an army feeds loses less by its general's skill.
	function C:general_mult(a: any): number
		local g = a.general
		if g == nil or g <= 0 then
			return 1.0
		end
		return 1.0 / (1.0 + self.dp.general_k * g)
	end

	--- Army rows for the clients: { aid, owner, troops, size, general, mode 1 front / 2 march, stance 1-3, target, dest,
	--- tile, state 1 idle / 2 march / 3 siege / 4 home, siege_p, siege_left }.
	local STANCE_N = { attack = 1, advance = 2, hold = 3 }
	local STATE_N = { idle = 1, march = 2, siege = 3, home = 4 }
	function C:_army_row(ar: any): { number }
		return {
			ar.aid,
			ar.owner,
			math.floor(ar.troops),
			math.floor(ar.size),
			ar.general,
			if ar.mode == "front" then 1 else 2,
			STANCE_N[ar.stance] or 3,
			ar.target,
			ar.dest,
			ar.tile,
			STATE_N[ar.state] or 1,
			ar.siege_p,
			ar.siege_left,
		}
	end

	--- The armies that changed since the last delta (a removed one: { aid, 0 }).
	function C:_army_delta(): { { number } }?
		if self.armies == nil or next(self._army_dirty) == nil then
			return nil
		end
		local out = {}
		for _, aid in self:_ordered_keys(self._army_dirty) do
			local ar = self.armies[aid]
			table.insert(out, if ar ~= nil then self:_army_row(ar) else { aid, 0 })
		end
		table.clear(self._army_dirty)
		return out
	end

	function C:_army_rows(): { { number } }
		local out = {}
		if self.armies == nil then
			return out
		end
		for _, k in self:_ordered_keys(self.armies) do
			table.insert(out, self:_army_row(self.armies[k]))
		end
		return out
	end

	--- The AI's armies, a few realms a second: raise one against a war enemy, send it, bring it home at peace.
	function C:_ai_armies_second()
		if self.armies == nil or self.wars == nil then
			return
		end
		local dp = self.dp
		local stride = dp.ai_army_stride
		local slot = (self.tick // TICK_RATE) % stride
		-- each realm's enemies, and every marching army by owner
		local foes = {}
		for _, k in self:_ordered_keys(self.wars) do
			local w = self.wars[k]
			foes[w.a] = foes[w.a] or {}
			foes[w.b] = foes[w.b] or {}
			table.insert(foes[w.a], w.b)
			table.insert(foes[w.b], w.a)
		end
		local W = self.W
		local P = self.P
		local function dist(a: number, b: number): number
			return math.abs(a % W - b % W) + math.abs(a // W - b // W)
		end
		for id = 1, self.owner_total do
			if id % stride ~= slot or self.o_ai[id] ~= 1 or self.o_alive[id] == 0 or self.o_kind[id] == Defs.KIND_TRIBE then
				continue
			end
			local mine = self:armies_of(id)
			local my_foes = foes[id]
			if my_foes == nil then
				-- at peace: armies go home and disband
				for _, ar in mine do
					self:disband_army(id, ar.aid)
				end
				continue
			end
			-- the nearest enemy to its capital is the one it fights
			local home = self.o_spawn_tile[id]
			local foe, fd = 0, math.huge
			for _, f in my_foes do
				if self.o_alive[f] == 1 then
					local d = dist(home, self.o_spawn_tile[f])
					if d < fd then
						foe, fd = f, d
					end
				end
			end
			if foe == 0 then
				continue
			end
			if #mine == 0 and self.o_troops[id] > dp.army_min * 4 then
				local aid = self:raise_army(id, self.o_troops[id] * dp.ai_army_share)
				if aid > 0 then
					table.insert(mine, self.armies[aid])
				end
			end
			for _, ar in mine do
				if ar.mode == "front" then
					if ar.target ~= foe then
						local stance = if self.o_troops[id] + ar.troops > self.o_troops[foe] * 0.8 then "attack" else "hold"
						self:army_front(id, ar.aid, foe, stance)
					end
				elseif ar.state == "idle" or ar.state == "march" then
					-- an enemy army near its land comes first: march to meet it
					local meet, md = -1, dp.ai_intercept
					for _, f in my_foes do
						for _, other in self:armies_of(f) do
							if other.mode == "march" and other.state ~= "home" then
								local d = math.min(dist(other.tile, home), dist(other.tile, ar.tile))
								if d < md and other.troops < ar.troops * 1.3 then
									meet, md = other.tile, d
								end
							end
						end
					end
					if meet >= 0 then
						if ar.dest ~= meet then
							self:army_march(id, ar.aid, meet)
						end
					elseif ar.state == "idle" then
						-- else the nearest province of the enemy to its army (its capital when it holds none whole)
						local best, bd = -1, math.huge
						for p = 1, P.n do
							if self.p_holder[p] == foe then
								local d = dist(P.cap[p], ar.tile)
								if d < bd then
									best, bd = P.cap[p], d
								end
							end
						end
						local cap = self.o_spawn_tile[foe]
						if cap >= 0 and dist(cap, ar.tile) < bd then
							best = cap
						end
						if best >= 0 then
							self:army_march(id, ar.aid, best)
						end
					end
				end
			end
		end
	end
end

return SimArmies
