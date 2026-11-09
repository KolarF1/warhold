--!native
-- Port of scripts/core/sim.gd: the authoritative match simulation (DESIGN.md §4). Pure logic, no
-- Instances; runs the server's multiplayer match and every local (title / solo) match. Construct,
-- add humans, submit intents, call step() at 10 Hz and feed each returned delta to a GameState.
--
-- CLASS / MIXIN PROTOCOL (binding for sim-systems; see build/notes/sim-core.md):
-- The GDScript chain SimState → SimAttacks → SimStructures → SimNaval → SimWarships → SimNukes → Sim
-- is flattened into ONE class table: each part module exposes install(C) that assigns its methods;
-- parts are installed in chain order (later ones override earlier ones; an override that needs
-- `super` keeps `local prev = C.name` inside its install), then Sim's own methods are assigned.
-- Sim.new(map, config) creates the instance (map: a WorldMap, or nil for WorldMap.get(config.map_id))
-- and runs, in order:
--   self.rng = Rng.new(seed)      (before _init_state, like `rng.seed = …` in sim.gd)
--   self:_init_state(map)         SimState   — every SimState member
--   self:_init_attacks()          SimAttacks — every SimAttacks member
--   self:_init_structures()       SimStructures (sim-systems)
--   self:_init_naval()            SimNaval      (sim-systems; nav = SimNav.shared(map))
--   self:_init_warships()         SimWarships   (sim-systems)
--   self:_init_nukes()            SimNukes      (sim-systems; GDScript had only member initialisers)
--   self.defense_posts_shoot = config.defense_posts_shoot (default Rules.DEFENSE_POST_SHOOTS)
--   _make_human_palette → _create_nations → _create_tribes → ai = SimAI.new(); ai:setup(self)
-- Every `_init_*` must assign ALL members its GDScript part declares (Luau has no field defaults).
local Defs = require("./Defs")
local Ev = require("./Ev")
local NumberFormat = require("./NumberFormat")
local Rules = require("./Rules")
local Rng = require("./Rng")
local GameState = require("./GameState")
local SimColors = require("./SimColors")
local SimState = require("./SimState")
local SimAttacks = require("./SimAttacks")
local SimStructures = require("./SimStructures")
local SimNaval = require("./SimNaval")
local SimWarships = require("./SimWarships")
local SimNukes = require("./SimNukes")
local SimArsenal = require("./SimArsenal")
local SimAI = require("./SimAI")
local Teams = require("./Teams")
local WorldMap = require("./WorldMap")
local Nations = require("../Data/Nations")
local RealmColors = require("../Data/RealmColors")
local Traits = require("../Data/Traits")
local Periods = require("../Data/Periods")
local PeriodTech = require("../Data/PeriodTech")
-- (the names a start date gives buildings and strikes follow the match: Data/PeriodTech)
PeriodTech.track(Defs.STRUCT_TITLES, function(k: string): any
	local i = Defs.struct_kind_from_name(k)
	return if i >= 0 then i else nil
end)
PeriodTech.track(Defs.NUKE_TITLES, function(k: string): any
	local i = Defs.nuke_kind_from_name(k)
	return if i >= 0 then i else nil
end)
local Coop = require("../Net/Coop")
local SimLandmarks = require("./SimLandmarks")
local SimDoctrines = require("./SimDoctrines")
local SimRivals = require("./SimRivals")
local SimModes = require("./SimModes")
local SimProvinces = require("./SimProvinces")
local SimEconomy = require("./SimEconomy")
local SimRulers = require("./SimRulers")
local SimDiplomacy = require("./SimDiplomacy")
local SimArmies = require("./SimArmies")
local SimAmbitions = require("./SimAmbitions")
local Eras = require("../Data/Eras")
local Depth = require("../Data/Depth")

local STRUCT_KINDS = SimState.STRUCT_KINDS
local TICK_RATE = 10

local readi32 = buffer.readi32

local Sim = {}
Sim.__index = Sim

SimState.install(Sim)
SimAttacks.install(Sim)
SimStructures.install(Sim)
SimNaval.install(Sim)
SimWarships.install(Sim)
SimNukes.install(Sim)
SimArsenal.install(Sim)
SimLandmarks.install(Sim)
SimDoctrines.install(Sim)
SimRivals.install(Sim)
SimModes.install(Sim)
SimProvinces.install(Sim)
SimEconomy.install(Sim)
SimRulers.install(Sim)
SimDiplomacy.install(Sim)
SimArmies.install(Sim)
SimAmbitions.install(Sim)

Sim.TICK_RATE = TICK_RATE
--- The flags the SHIPPED game turns on (Conquer the World's own systems). `Sim.new` never reads this:
--- it defaults every one of them to off, so the inherited exact-number tests keep proving the base.
--- Session and ServerMain apply it to a match's config, as do the tests of the systems themselves.
Sim.DEFAULTS = { landmarks = true, doctrines = true, world_events = true, rivals = true }

--- `config` with the shipped flags filled in where the caller did not say.
function Sim.with_defaults(config: { [string]: any }): { [string]: any }
	for k, v in Sim.DEFAULTS do
		if config[k] == nil then
			config[k] = v
		end
	end
	return config
end
--- Owners whose start lies within these many tiles (of the original 1024-wide grid; scaled by the
--- map's R.LEGACY_LIN) count as neighbours for colour contrast.
Sim.COLOR_NEAR_NATION = 70
Sim.COLOR_NEAR_HUMAN = 120
--- Every tribe's colour: one flat warm grey shared by all tribes,
--- so tribes read as neutral filler and only players and nations are colourful.
Sim.TRIBE_COLOR = Defs.html_rgba("#d1cdc7")
Sim.PROF_NAMES = { "intents", "economy", "ai", "attacks", "units", "ports", "factories", "nukes", "misc" }

local function clock_us(): number
	return os.clock() * 1e6
end

-- =============================================================================================
-- Construction
-- =============================================================================================

--- Sim.new(map, config): config = {map_id (used when `map` is nil; default MapList.DEFAULT), seed,
--- difficulty (0..2), tribes (default: Sim.default_tribes(map)), max_humans, time_limit_s,
--- spawn_ticks, solo_countdown_ticks (a solo match: ticks from placing the capital to the start;
--- default Rules.SOLO_COUNTDOWN_TICKS), defense_posts_shoot, nations (false: no manifest nations),
--- nation_limit (that many of the manifest's nations, picked at random), teams (a team game:
--- a number of teams, Teams.DUOS / TRIOS / QUADS / HVN; see assign_teams)}.
function Sim.new(p_map: any, config: { [string]: any }?): any
	local cfg = config or {}
	if p_map == nil then
		p_map = WorldMap.get(if type(cfg.map_id) == "string" then cfg.map_id else nil)
	end
	local self: any = setmetatable({}, Sim)
	local seed = if type(cfg.seed) == "number" then Defs.trunc(cfg.seed) else 1
	self.rng = Rng.new(seed)
	self.difficulty = math.clamp(Defs.trunc(tonumber(cfg.difficulty) or 1), 0, 2)
	--- Hardcore (Data/Modes): Brutal nations whatever was asked, every bot player smart and harsh, no world events.
	self.hardcore = cfg.hardcore == true
	if self.hardcore then
		self.difficulty = 2
	end
	self.max_humans = math.max(Defs.trunc(tonumber(cfg.max_humans) or 0), 0)
	--- Map id (snapshots carry it so mirrors build GameState on the same map).
	self.map_id = p_map.id
	--- The start date (Data/Periods key; nil: today's world). Only a map that offers it keeps it.
	self.period = if type(cfg.period) == "string" and Periods.seats(cfg.period, p_map.id) ~= nil then cfg.period else nil
	PeriodTech.apply(self.period)
	self.tribe_count = math.clamp(Defs.trunc((tonumber(cfg.tribes) or Sim.default_tribes(p_map)) * (tonumber(cfg.tribes_scale) or 1)), 0, 700)
	self.time_limit_s = math.max(Defs.trunc(tonumber(cfg.time_limit_s) or 0), 0)
	self.spawn_total = math.max(Defs.trunc(tonumber(cfg.spawn_ticks) or Rules.DEFAULT_SPAWN_TICKS), 10)
	--- True when max_humans == 1 (spawn phase waits for the player's pick, then counts down 5 s).
	self.solo = self.max_humans == 1
	--- Spawn phase ticks left; -1 while a solo match waits for the first pick.
	self.spawn_left = -1
	self.solo_countdown = math.max(Defs.trunc(tonumber(cfg.solo_countdown_ticks) or Rules.SOLO_COUNTDOWN_TICKS), 1)
	--- Absolute tick at which the match ends by time (0 = no limit).
	self.time_limit_ticks = 0
	self.winner = 0
	self.over_reason = -1
	self.nation_count = 0
	--- Team games (Core/Teams): the config (nil: every owner for itself), the team names once
	--- assign_teams ran, the team that won, and per team the players put on it so far (their shades).
	self.team_config = cfg.teams
	self.team_mode = cfg.teams ~= nil
	self.team_names = {} :: { string }
	self.winner_team = 0
	self._team_n = {} :: { [number]: number }
	self.nation_limit = if type(cfg.nation_limit) == "number" then math.max(Defs.trunc(cfg.nation_limit), 0) else nil
	--- Wall-clock microseconds of the last step() (diagnostics).
	self.last_step_usec = 0
	--- When true, step() accumulates per-subsystem microseconds into `prof` (see PROF_NAMES).
	self.profile = false
	self.prof = table.create(#Sim.PROF_NAMES, 0)
	self._intents = {} :: { { any } }
	self._human_disk = {} :: { [number]: { number } }
	self._human_colors = {} :: { number }
	--- Humans whose start disk is claimed at the beginning of the next tick (their colour is chosen
	--- at the pick, and a re-sent OWNER_ADD must reach the mirror while they hold no land).
	--- id → tile, plus the ids in pick order (GDScript Dictionary insertion order).
	self._pending_spawn = {} :: { [number]: number }
	--- bot player id → spawn-phase ticks left at which it takes its random start
	self._bot_spawn_at = {} :: { [number]: number }
	self._pending_order = {} :: { number }
	--- humans given a random start because they never picked (a message says so when they land)
	self._auto_placed = {} :: { [number]: boolean }
	self._force_stats = false
	self.last_capitulation = -100000

	-- Coop.check(): Session builds local matches inside a Coop job (time-sliced over frames);
	-- a no-op elsewhere (server, Lune).
	self:_init_state(p_map)
	Coop.check()
	self:_init_attacks()
	self:_init_structures()
	-- (a depth match: its provinces, docs/DEPTH_DESIGN.md)
	self:_init_provinces(cfg)
	self:_init_economy()
	self:_init_rulers()
	self:_init_diplomacy()
	self:_init_armies()
	self:_init_ambitions()
	Coop.check()
	self:_init_naval()
	Coop.check()
	self:_init_warships()
	self:_init_nukes()
	self:_init_arsenal()
	--- How fast the ages (and the Crown) come on this map: 1 on World, under 1 on a map that is one big landmass
	--- (Data/Eras.scale_for_map); config `age_scale` sets it outright. Read by _init_doctrines and _init_modes.
	self.age_scale = if type(cfg.age_scale) == "number" and cfg.age_scale > 0 then cfg.age_scale else Eras.scale_for_map(p_map.id)
	-- (a Long war is the deeper normal: its ages run longer; Quick keeps today's pace, docs/DEPTH_DESIGN.md)
	if self.depth == "long" and not (type(cfg.age_scale) == "number" and cfg.age_scale > 0) then
		self.age_scale *= Depth.LONG_AGE_SCALE
	end
	self:_init_landmarks(cfg)
	self:_init_doctrines(cfg, seed)
	self:_init_rivals(cfg, seed)
	self:_init_modes(cfg)
	Coop.check()
	if type(cfg.defense_posts_shoot) == "boolean" then
		self.defense_posts_shoot = cfg.defense_posts_shoot
	else
		self.defense_posts_shoot = Rules.DEFENSE_POST_SHOOTS
	end
	self:_make_human_palette()
	-- Nations turned off in the config (nations = false): no manifest nations.
	if cfg.nations ~= false then
		self:_create_nations()
	end
	Coop.check()
	self:_create_tribes()
	Coop.check()
	self.ai = SimAI.new()
	self.ai:setup(self)
	self:_rivals_setup()
	Coop.check()
	if self.max_humans == 0 then
		self:_start_playing()
	else
		self.phase = Defs.PHASE_SPAWN
		self.spawn_left = if self.solo then -1 else self.spawn_total
		if not self.solo and self.time_limit_s > 0 then
			self.time_limit_ticks = self.spawn_total + self.time_limit_s * TICK_RATE
		end
	end
	-- The initial state travels in snapshot(); start the first delta clean.
	self.d_tiles = {}
	self.d_flags = {}
	self.d_ev = {}
	table.clear(self.pending_out)
	return self
end

--- Default tribe count for `map`: Rules.DEFAULT_TRIBES (400 on a map at
--- full size). A smaller build ("id@80") gets fewer in proportion to its area, so compact
--- maps (a quarter of the area) get 100.
--- Tribes on a real-world map (Data/RealmColors' maps), today and in every start date: none (2026-11-09, the owner: "as
--- little fake nations as possible ... the goal is for there to be none"). Its real nations and peoples hold the land
--- (tools/maps/coverage.py); what no one reaches is open land. nil: the area's count, as on every other map.
Sim.REAL_MAP_TRIBES = 0

function Sim.default_tribes(map: any): number
	local base = if type(map) == "table" then string.match(tostring(map.id or ""), "^([^@]*)") else nil
	if Sim.REAL_MAP_TRIBES ~= nil and base ~= nil and (RealmColors :: any)[base] ~= nil then
		return Sim.REAL_MAP_TRIBES
	end
	local s = if type(map) == "table" then (tonumber(map.scale) or 1.0) else 1.0
	return math.floor(Rules.DEFAULT_TRIBES * s * s + 0.5)
end

-- =============================================================================================
-- Public API
-- =============================================================================================

--- Registers a human (not yet spawned). Re-joining with the same key returns the same id.
function Sim.add_human(self: any, key: string, display_name: string, banner_hex: string?): number
	local old = self.human_keys[key]
	if old ~= nil then
		if self.o_alive[old] == 1 then
			-- Reconnect: the (possibly passive) nation is theirs again.
			self.o_left[old] = 0
			return old
		end
		if self.o_spawned[old] == 0 then
			-- Joined and left before spawning: revive the same id instead of burning a new one.
			self.o_alive[old] = 1
			self.o_left[old] = 0
			self.o_troops[old] = Rules.START_TROOPS_HUMAN
			self.o_gold[old] = Rules.START_GOLD
			self:ev({ Ev.OWNER_ADD, old, self.o_name[old], self.o_color[old], Defs.KIND_HUMAN, self.o_team[old] })
			return old
		end
	end
	local cols = self._human_colors
	local col = cols[#self.humans % #cols + 1]
	-- their banner's colour, unless another player already flies it
	if type(banner_hex) == "string" then
		local want = Defs.html_rgba(banner_hex)
		local taken = false
		for _, h in self.humans do
			taken = taken or self.o_color[h] == want
		end
		if not taken then
			col = want
		end
	end
	local nm = if type(display_name) == "string" and display_name ~= "" then display_name else "Ruler"
	local id = self:add_owner(nm, col, Defs.KIND_HUMAN)
	if id <= 0 then
		return 0
	end
	self.human_keys[key] = id
	table.insert(self.humans, id)
	self.o_troops[id] = Rules.START_TROOPS_HUMAN
	return id
end

--- Registers a bot player: an AI commander that looks like a human player everywhere (kind HUMAN,
--- human troops / colours, a player-style name) and plays like an AI nation. It picks a random start
--- at a random moment of the spawn phase, like a person would (public matches fill empty slots with
--- these; they are meant to be indistinguishable from players).
--- Public matches were too hard for new players with every bot player on the nation AI at full human
--- strength (2026-09-27): only SMART_BOTS of them play like that; the rest are novices — the
--- Easy nation AI (slow attacks, long peace with humans, few boats, no warship hunting, late nukes)
--- with Easy nation troop numbers (half the troop cap, x0.9 growth, 12.5K to start).
--- Smart bot players have the match's nation troop numbers (cap, growth and start at the match
--- difficulty; 2026-11-06: on a person's numbers, double an Easy nation's cap, the two smart bots
--- held 6x a nation's land by minute 5 and won 5 of 5 public-style World runs).
--- (2026-11-09, the owner, again: multiplayer's bots too easy. 4 -> 8 smart, and they play at Hard.)
Sim.SMART_BOTS = 8
Sim.NOVICE_SKILL = 0
--- Smart bot players play at this difficulty whatever the match's (public matches run Medium nations).
Sim.SMART_SKILL = 2
--- Towards players, though, they are no harsher than Rules.SMART_VS_PLAYERS' AI (human_difficulty).

--- The AI difficulty `id` plays at (its own for bot players, else the match's).
function Sim.ai_difficulty(self: any, id: number): number
	local s = self.o_skill[id]
	return if s ~= nil and s >= 0 then s else self.difficulty
end

--- The difficulty whose human-protection rules `id` follows (Rules.SMART_VS_PLAYERS for a smart bot
--- player, else the one it plays at).
function Sim.human_difficulty(self: any, id: number): number
	local d = self:ai_difficulty(id)
	if self.o_bot[id] == 1 and self.o_skill[id] ~= Sim.NOVICE_SKILL and not self.hardcore then
		return math.min(d, Rules.SMART_VS_PLAYERS)
	end
	return d
end

--- A novice bot player (weaker troop numbers).
function Sim.is_novice_bot(self: any, id: number): boolean
	return self.o_bot[id] == 1 and self.o_skill[id] == Sim.NOVICE_SKILL
end

--- The (kind, difficulty) whose troop numbers `id` has (cap, growth, start): bot players a nation's
--- (novices Easy, smart ones the match's difficulty), everyone else their own kind at the match's.
function Sim.troop_rules_of(self: any, id: number): (number, number)
	if self.o_bot[id] == 1 then
		return Defs.KIND_NATION, if self.o_skill[id] == Sim.NOVICE_SKILL then Sim.NOVICE_SKILL else self.difficulty
	end
	return self.o_kind[id], self.difficulty
end

--- Troops `id` starts with (bot players: a nation's start, see troop_rules_of).
function Sim._start_troops_of(self: any, id: number): number
	if self.o_bot[id] == 1 then
		local kind, d = self:troop_rules_of(id)
		return Rules.start_troops(kind, d)
	end
	return Rules.START_TROOPS_HUMAN
end

--- `smart`: plays the nation AI at SMART_SKILL with the match's nation troop numbers; otherwise a
--- novice (see SMART_BOTS).
function Sim.add_bot_player(self: any, display_name: string, smart: boolean?): number
	local id = self:add_human("bot:" .. tostring(self.owner_total + 1) .. ":" .. display_name, display_name)
	if id <= 0 then
		return 0
	end
	self.o_ai[id] = 1
	self.o_bot[id] = 1
	self.o_skill[id] = if smart == false then Sim.NOVICE_SKILL elseif self.hardcore then 2 else Sim.SMART_SKILL
	self.o_troops[id] = self:_start_troops_of(id)
	self:_rivals_bot(id)
	-- spawn when this many spawn-phase ticks are left (between 85% and 15% of the phase)
	local total = self.spawn_total
	self._bot_spawn_at[id] = self.rng:randi_range(math.floor(total * 0.15), math.floor(total * 0.85))
	return id
end

--- Adds `n` bot players with names from `names` (1-based; missing names get generated ones): SMART_BOTS
--- of them (random picks) smart, the rest novices.
function Sim.add_bot_players(self: any, n: number, names: { string }?): { number } -- (their ids)
	local out = {}
	local smart = {}
	local left = if self.hardcore then n else math.min(Sim.SMART_BOTS, n)
	for k = 1, n do
		-- k is smart with probability (smart still to place) / (bots still to add)
		if left > 0 and self.rng:randi() % (n - k + 1) < left then
			smart[k] = true
			left -= 1
		end
	end
	for k = 1, n do
		local nm = if names and names[k] then names[k] else ("Player" .. tostring(1000 + k))
		local id = self:add_bot_player(nm, smart[k] == true)
		if id <= 0 then
			break
		end
		table.insert(out, id)
	end
	return out
end

--- Human left: their nation (if any) stays as a passive, AI-less nation.
function Sim.remove_human(self: any, owner_id: number)
	if owner_id <= 0 or owner_id > self.owner_total or self.o_kind[owner_id] ~= Defs.KIND_HUMAN then
		return
	end
	self.o_left[owner_id] = 1
	if self.o_spawned[owner_id] == 0 and self.o_alive[owner_id] == 1 then
		self.o_alive[owner_id] = 0
		self:ev({ Ev.OWNER_OUT, owner_id, 0 })
	end
end

--- A paid takeover of the nation that eliminated you (2026-09-28; public matches too, provided
--- the target is an AI): the fallen human `old` takes command of AI nation `target` — its land, troops,
--- gold, structures and alliances stay; its AI stops and it plays by human rules from now on, under
--- the player's name (its colour stays). Nations only: never a tribe, never a bot player (in a public
--- match that would give the bot away as not a person). True when done.
function Sim.can_take_over(self: any, old: number, target: number): boolean
	return self.phase == Defs.PHASE_PLAYING
		and old > 0
		and old <= self.owner_total
		and self.o_kind[old] == Defs.KIND_HUMAN
		and self.o_alive[old] == 0
		and target > 0
		and target <= self.owner_total
		and self.o_kind[target] == Defs.KIND_NATION
		and self.o_alive[target] == 1
		and self.o_spawned[target] == 1
		and self.o_tiles[target] > 0
end

function Sim.take_over(self: any, old: number, target: number): boolean
	if not self:can_take_over(old, target) then
		return false
	end
	self.o_kind[target] = Defs.KIND_HUMAN
	-- the nation plays with its new commander's Arsenal
	self.o_unlock[target] = self.o_unlock[old]
	self.o_ai[target] = 0
	self.o_skill[target] = -1
	self.o_left[target] = 0
	for key, id in self.human_keys do
		if id == old then
			self.human_keys[key] = target
		end
	end
	table.insert(self.humans, target)
	-- it goes by the player's name from now on (2026-09-28: the nation is renamed to the taker's
	-- username); its colour stays
	local was = self.o_name[target]
	self.o_name[target] = self.o_name[old]
	self:ev({ Ev.OWNER_ADD, target, self.o_name[target], self.o_color[target], Defs.KIND_HUMAN, self.o_team[target] })
	self:msg(target, Defs.MSG_GOOD, "You now rule " .. was)
	return true
end

--- Queues an intent dictionary for the next step().
function Sim.submit(self: any, owner_id: number, intent: { [string]: any })
	table.insert(self._intents, { owner_id, intent })
end

--- Solo convenience: place (or move) the human's start immediately. True when accepted.
function Sim.human_start(self: any, owner_id: number, tile: number): boolean
	return self:_intent_spawn(owner_id, tile)
end

--- Ticks until the spawn phase ends (-1 while a solo match waits for the pick; 0 once playing).
function Sim.spawn_ticks_left(self: any): number
	return if self.phase == Defs.PHASE_SPAWN then self.spawn_left else 0
end

--- Number of owner ids allocated (valid ids are 1..owner_count()).
function Sim.owner_count(self: any): number
	return self.owner_total
end

--- Advances one tick and returns the delta {t, tiles, flags, stats?, ev} (see READY-core-api).
function Sim.step(self: any): { [string]: any }
	local t0 = clock_us()
	self.tick += 1
	local tick = self.tick
	if self.phase ~= Defs.PHASE_OVER then
		self.path_budget = 2
		if tick % 10 == 0 then
			self:refill_boat_tokens()
		end
		self:_claim_pending_spawns()
		if self.profile then
			self:_step_profiled()
		else
			-- A tick first advances what is already under way (the troop
			-- and gold income first: it starts at spawn) and only then starts the actions
			-- of this turn's intents, so income is computed on the troops held before this tick's
			-- orders (and a city finishing now raises the cap from the next tick).
			if self.phase == Defs.PHASE_PLAYING then
				self:_provinces_tick()
				self:_economy_tick()
				self:_alliances_tick()
			end
			self:_process_intents()
			if self.phase == Defs.PHASE_SPAWN then
				self:_spawn_phase_tick()
			else
				self:construction_tick()
				self.ai:tick(self)
				self:attacks_tick()
				self:units_tick()
				self:warships_tick()
				self:ports_tick()
				self:factories_tick()
				self:arsenal_tick()
				self:nukes_tick()
				self:_diplomacy_tick()
				self:_process_eliminations()
				if tick % 10 == 0 then
					self:_check_victory()
				end
			end
		end
	else
		table.clear(self._intents)
	end
	local d: { [string]: any } = { t = tick, tiles = self.d_tiles, flags = self.d_flags, ev = self.d_ev }
	if self.depth ~= nil then
		self:_depth_delta(d)
	end
	if tick % 5 == 0 or self._force_stats then
		d.stats = self:_stats_rows()
		self._force_stats = false
	end
	self.d_tiles = {}
	self.d_flags = {}
	self.d_ev = {}
	self.last_step_usec = clock_us() - t0
	return d
end

function Sim._step_profiled(self: any)
	local t = clock_us()
	if self.phase == Defs.PHASE_PLAYING then
		self:_provinces_tick()
		self:_economy_tick()
		self:_alliances_tick()
	end
	t = self:_lap(2, t)
	self:_process_intents()
	t = self:_lap(1, t)
	if self.phase == Defs.PHASE_SPAWN then
		self:_spawn_phase_tick()
		return
	end
	self:construction_tick()
	t = self:_lap(2, t)
	self.ai:tick(self)
	t = self:_lap(3, t)
	self:attacks_tick()
	t = self:_lap(4, t)
	self:units_tick()
	self:warships_tick()
	t = self:_lap(5, t)
	self:ports_tick()
	t = self:_lap(6, t)
	self:factories_tick()
	t = self:_lap(7, t)
	self:arsenal_tick()
	self:nukes_tick()
	t = self:_lap(8, t)
	self:_diplomacy_tick()
	self:_process_eliminations()
	if self.tick % 10 == 0 then
		self:_check_victory()
	end
	self:_lap(9, t)
end

--- slot is 1-based (PROF_NAMES[slot]).
function Sim._lap(self: any, slot: number, since: number): number
	local now = clock_us()
	self.prof[slot] += now - since
	return now
end

--- Full state for GameState:load_snapshot() / late joiners (see READY-core-api for the shape).
function Sim.snapshot(self: any): { [string]: any }
	local owners = {}
	for id = 1, self.owner_total do
		table.insert(owners, {
			id,
			self.o_name[id],
			self.o_color[id],
			self.o_kind[id],
			self.o_team[id],
			self.o_alive[id] == 1,
			self.o_tiles[id],
			Defs.trunc(self.o_troops[id]),
			self:_gold_int(id),
			Defs.trunc(self.o_cap[id]),
			Defs.trunc(self.o_income[id] + self.o_bonus_rate[id]),
			self.o_traitor_until[id],
			if self.o_spawned[id] == 1 then self.o_spawn_tile[id] else -1,
		})
	end
	-- allies: {a, b, expires_at, renewal asked bits}; requests: {from, to, tick made}
	local allies = {}
	for _, k in self:_ordered_keys(self.alliances) do
		table.insert(allies, { k // 1024, k % 1024, self.ally_expires[k], self.ally_ext[k] })
	end
	local reqs = {}
	for _, k in self:_ordered_keys(self.requests) do
		table.insert(reqs, { k // 1024, k % 1024, self.requests[k] })
	end
	local n = self.N
	local fl = buffer.create(n)
	buffer.copy(fl, 0, self.flags, 0, n)
	local eras_rows, doctrine_rows, edict_rows, world_event_row = self:_doctrine_snapshot()
	local crown_row, crown_rows = self:_crown_snapshot()
	return {
		map_id = self.map.id,
		map_w = self.W,
		map_h = self.H,
		t = self.tick,
		phase = self.phase,
		phase_left = self:spawn_ticks_left(),
		time_limit_ticks = self.time_limit_ticks,
		playing_since = self.playing_since,
		mirvs_launched = self.mirvs_launched,
		mirvs_by = self:mirvs_rows(),
		built = self:built_rows(),
		winner = self.winner,
		over_reason = self.over_reason,
		teams = if #self.team_names > 0 then self.team_names else nil,
		winner_team = if self.winner_team ~= 0 then self.winner_team else nil,
		owner = GameState.encode_grid(self.owner),
		flags = fl,
		owners = owners,
		structs = self:struct_rows(),
		roads = self:road_rows(),
		units = self:unit_rows(),
		nukes = self:nuke_rows(),
		shells = self:shell_rows(),
		sam_missiles = self:sam_rows(),
		attacks = self:attack_rows(),
		allies = allies,
		requests = reqs,
		eras = eras_rows,
		doctrine = doctrine_rows,
		edict = edict_rows,
		calls = self:_call_rows(),
		world_event = world_event_row,
		persona_seed = if self.rivals_on then self.persona_seed else nil,
		nemesis = self:_nemesis_rows(),
		mode = self.mode,
		win_share = self.win_share,
		crown = crown_row,
		crown_rows = crown_rows,
		traits = self:_trait_rows(),
		period = self.period,
		depth = if self.depth ~= nil then self:_depth_snapshot() else nil,
	}
end

--- The depth block of a snapshot (docs/DEPTH_DESIGN.md): the pace, and every system's state.
function Sim._depth_snapshot(self: any): { [string]: any }
	return { key = self.depth, h = self:_province_rows(), r = self:_realm_rows(), k = self:_ruler_rows(), d = self:_diplomacy_rows(), a = self:_army_rows(), m = (self:_ambition_rows()) }
end

--- The depth part of a delta: only what changed (`dp`).
function Sim._depth_delta(self: any, d: { [string]: any })
	local dp: { [string]: any }? = nil
	if #self.d_prov > 0 then
		dp = { h = self.d_prov }
		self.d_prov = {}
	end
	if self.d_realm ~= nil and #self.d_realm > 0 then
		dp = dp or {}
		dp.r = self.d_realm
		self.d_realm = {}
	end
	if self.d_ruler ~= nil and #self.d_ruler > 0 then
		dp = dp or {}
		dp.k = self.d_ruler
		self.d_ruler = {}
	end
	if self.d_amb ~= nil and #self.d_amb > 0 then
		dp = dp or {}
		dp.m = self.d_amb
		self.d_amb = {}
	end
	local armies = self:_army_delta()
	if armies ~= nil then
		dp = dp or {}
		dp.a = armies
	end
	-- (wars, truces and vassals: whole when they changed, and every 5 s while a war runs, for its score)
	if self.wars ~= nil and (self._dip_dirty or (self.tick % 50 == 0 and next(self.wars) ~= nil)) then
		self._dip_dirty = false
		dp = dp or {}
		dp.d = self:_diplomacy_rows()
	end
	if dp ~= nil then
		d.dp = dp
	end
end

-- =============================================================================================
-- Setup
-- =============================================================================================

local HUMAN_HEX = {
	"#ffd23f",
	"#3bceac",
	"#ee4266",
	"#5e60ce",
	"#f77f00",
	"#80ed99",
	"#ff99c8",
	"#00b4d8",
	"#c77dff",
	"#f9c74f",
	"#e63946",
	"#90be6d",
	"#ff6d00",
	"#4cc9f0",
	"#b5179e",
	"#fcbf49",
}

function Sim._make_human_palette(self: any)
	for _, h in HUMAN_HEX do
		table.insert(self._human_colors, Defs.html_rgba(h))
	end
end

-- Nation colours by ISO code (the authored palette, Data/Nations), for flags that match.
local NATION_COLOR: { [string]: string } = {}
for _, nd in Nations :: any do
	if type(nd) == "table" and nd.code ~= nil and nd.color ~= nil then
		NATION_COLOR[string.lower(tostring(nd.code))] = tostring(nd.color)
	end
end

--- Nations of the map's manifest: each starts on its seat, or the nearest free land to it (2026-11-09, the owner:
--- "Morocco shouldn't spawn in Spain": a random tile within +-NATION_SPAWN_DELTA put most realms 7-25 tiles off their
--- seat, across a strait or a border; tools/maps/spawn_check.luau measures it), within NATION_SEAT_REACH tiles, else
--- a random start; a random start too when it has no coordinates. Colours: the authored colour of the flag's country
--- (minimal nudge away from neighbours), else the nation-style candidate most distinct from them.
--- The historical strengths on the map: { { owner id, Data/Traits key } } by id (for the snapshot).
function Sim._trait_rows(self: any): { { any } }
	local out = {}
	for _, id in self:_ordered_keys(self.o_trait or {}) do
		table.insert(out, { id, self.o_trait[id] })
	end
	return out
end

--- How far (tiles, square rings) a nation looks from its seat for free land before taking a random start.
Sim.NATION_SEAT_REACH = 60

function Sim._create_nations(self: any)
	local R = self.R
	local list = self.map:load_nations()
	-- a start date: that year's realms in place of today's (Data/Periods; seats in full-size tiles, scaled to the map)
	local prows = if self.period ~= nil then Periods.seats(self.period, self.map_id) else nil
	if prows ~= nil then
		list = {}
		local W, H = self.W, self.H
		local sc = tonumber(self.map.scale) or 1
		for _, r in prows do
			local x = math.clamp(math.floor(r.x * sc), 0, W - 1)
			local y = math.clamp(math.floor(r.y * sc), 0, H - 1)
			table.insert(list, { name = r.name, color = r.color, trait = r.trait, x = x, y = y, tile = y * W + x, period = true })
		end
	end
	local limit = self.nation_limit
	if limit ~= nil and limit < #list then
		-- (Humans Vs Nations: as many nations as players, picked at random)
		local pool = table.clone(list)
		for i = #pool, 2, -1 do
			local j = self.rng:randi_range(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		list = table.move(pool, 1, limit, 1, {})
	end
	local picked = {} :: { [number]: boolean }
	-- (a real-world map: each realm in its own country's colour, Data/RealmColors, by the place's name; 2026-11-08)
	local real = (RealmColors :: any)[(string.match(tostring(self.map_id or ""), "^([^@]*)"))]
	for _, nd in list do
		if type(nd) ~= "table" then
			continue
		end
		local hex = if type(nd.color) == "string" then nd.color elseif real ~= nil and nd.name ~= nil then real[tostring(nd.name)] else nil
		if hex == nil and nd.flag ~= nil then
			hex = NATION_COLOR[string.lower(tostring(nd.flag))]
		end
		local col = if hex ~= nil then Defs.html_rgba(hex) else 0x888888FF
		local id = self:add_owner(tostring(nd.name or "Nation"), col, Defs.KIND_NATION)
		if id <= 0 then
			break
		end
		-- its historical strength (Data/Traits): a period's realm names its own; on today's real maps, by the place
		local trait = if nd.period == true then (if nd.trait ~= nil then Traits.of_row(nd) else nil)
			elseif real ~= nil then Traits.of_row(nd)
			else nil
		if trait ~= nil then
			self.o_trait[id] = trait
			self.mults_on = true
		end
		picked[id] = hex ~= nil
		self.nation_count += 1
		Coop.check()
		self.o_troops[id] = Rules.start_troops(Defs.KIND_NATION, self.difficulty)
		local t = -1
		local at = tonumber(nd.tile) or -1
		if at >= 0 and at < self.N then
			t = self:_nearest_free_land(at, Sim.NATION_SEAT_REACH)
		end
		if t < 0 then
			t = self:_random_start(id)
		end
		if t >= 0 then
			self:_spawn_owner(id, t, R.SPAWN_RADIUS)
		end
	end
	for id = 1, self.owner_total do
		if self.o_spawn_tile[id] < 0 then
			continue
		end
		Coop.check()
		local refs = self:_colour_refs(id, Sim.COLOR_NEAR_NATION)
		if picked[id] then
			-- Authored colours stay unless a nearby capital's colour is too similar (minimal nudge).
			self.o_color[id] = SimColors.nudge(self.o_color[id], refs)
		else
			self.o_color[id] = SimColors.pick(SimColors.human_palette(), refs, self.rng)
		end
	end
end

--- A random start (for tribes, unplaced nations and humans who never
--- picked): of 1000 random tiles of the whole map, the first that is free land, not
--- next to anyone's land, whose whole spawn disk is free land, and at least TRIBE_SPAWN_MIN_DIST (manhattan) from every
--- other start. Never on frozen waste (Rules.frozen_from) while warmer land is free (2026-11-09, the owner: most bot
--- players began in Antarctica: with real nations everywhere only the ice was that far from every start). When no tile
--- is that far, the farthest one found. -1 when none is found.
function Sim._random_start(self: any, id: number): number
	local map = self.map
	if map.land_count <= 0 then
		return -1
	end
	local N = self.N
	local rng = self.rng
	local owner = self.owner
	local geo_manhattan = self.geo_manhattan
	local min_d = self.R.TRIBE_SPAWN_MIN_DIST
	local r = self.R.SPAWN_RADIUS
	local o_spawn_tile = self.o_spawn_tile
	local o_spawned = self.o_spawned
	local total = self.owner_total
	local frozen = self.frozen_from
	local best, best_d = -1, -1
	local cold = -1
	for tries = 1, 1000 do
		if tries % 50 == 0 then
			Coop.check()
		end
		local c = rng:randi() % N
		if not self:claimable(c) or readi32(owner, c * 4) ~= 0 or self:_owned_near(c) then
			continue
		end
		if c >= frozen then
			if cold < 0 and self:_spawn_disk_free(c, r) then
				cold = c
			end
			continue
		end
		local d = math.huge
		for o = 1, total do
			if o ~= id and o_spawned[o] == 1 then
				local st = o_spawn_tile[o]
				if st >= 0 then
					d = math.min(d, geo_manhattan(st, c))
					if d < min_d and d <= best_d then
						break
					end
				end
			end
		end
		if d >= min_d then
			if self:_spawn_disk_free(c, r) then
				return c
			end
		elseif d > best_d and self:_spawn_disk_free(c, r) then
			best, best_d = c, d
		end
	end
	return if best >= 0 then best else cold
end

--- True when a 4-neighbour of `t` is owned (an unowned tile on someone's border).
function Sim._owned_near(self: any, t: number): boolean
	local owner = self.owner
	local W = self.W
	local x = t % W
	if x > 0 and readi32(owner, (t - 1) * 4) ~= 0 then
		return true
	end
	if x < W - 1 and readi32(owner, (t + 1) * 4) ~= 0 then
		return true
	end
	if t >= W and readi32(owner, (t - W) * 4) ~= 0 then
		return true
	end
	if t < self.N - W and readi32(owner, (t + W) * 4) ~= 0 then
		return true
	end
	return false
end

--- The spawn disk: every tile within euclidean distance `radius` of the corner of the
--- start tile, as a 1-based array (inside the map).
function Sim._spawn_disk(self: any, center: number, radius: number): { number }
	local W, H = self.W, self.H
	local cx = center % W
	local cy = center // W
	local r2 = radius * radius
	local ri = math.ceil(radius) + 1
	local out = {}
	for dy = -ri, ri do
		local y = cy + dy
		if y < 0 or y >= H then
			continue
		end
		local fy = dy + 0.5
		for dx = -ri, ri do
			local x = cx + dx
			if x < 0 or x >= W then
				continue
			end
			local fx = dx + 0.5
			if fx * fx + fy * fy <= r2 then
				table.insert(out, y * W + x)
			end
		end
	end
	return out
end

--- True when every tile of the spawn disk around `c` is free contestable land.
function Sim._spawn_disk_free(self: any, c: number, radius: number): boolean
	local owner = self.owner
	for _, t in self:_spawn_disk(c, radius) do
		if readi32(owner, t * 4) ~= 0 or not self:claimable(t) then
			return false
		end
	end
	return true
end

--- Tribes: `tribe_count` tribes at random starts (Sim._random_start).
function Sim._create_tribes(self: any)
	local names = WorldMap.load_tribe_names()
	local rng = self.rng
	local order = {}
	for i = 0, #names - 1 do
		order[i] = i
	end
	for i = #names - 1, 1, -1 do
		local j = rng:randi() % (i + 1)
		order[i], order[j] = order[j], order[i]
	end
	local spawn_r = self.R.SPAWN_RADIUS
	local nn = #names
	for k = 0, self.tribe_count - 1 do
		local tribe_name
		if nn > 0 then
			tribe_name = names[order[k % nn] + 1]
			if k >= nn then
				tribe_name ..= " " .. tostring(k // nn + 1)
			end
		else
			tribe_name = "Clan " .. tostring(k + 1)
		end
		local id = self:add_owner(tribe_name, Sim.TRIBE_COLOR, Defs.KIND_TRIBE)
		if id <= 0 then
			break
		end
		self.o_troops[id] = Rules.START_TROOPS_TRIBE
		Coop.check()
		local t = self:_random_start(id)
		if t >= 0 then
			self:_spawn_owner(id, t, spawn_r)
		end
		if self.o_spawned[id] == 0 or self.o_tiles[id] == 0 then
			-- No room left: this tribe never existed as far as the match is concerned.
			self.o_alive[id] = 0
		end
	end
end

--- `radius` in tiles of the original 1024-wide grid (scaled by the map's LEGACY_LIN).
function Sim._colour_refs(self: any, id: number, radius: number, kind: number?): { any }
	return SimColors.refs_near(self, id, radius * self.R.LEGACY_LIN, kind or -1)
end

--- True when nobody owns a tile within `r` (latitude-corrected) of `t`.
function Sim._area_free(self: any, t: number, r: number): boolean
	local owner = self.owner
	for _, c in self:disk_tiles(t, r, false) do
		if readi32(owner, c * 4) ~= 0 then
			return false
		end
	end
	return true
end

function Sim._nearest_free_land(self: any, t: number, r: number): number
	local owner = self.owner
	if self:claimable(t) and readi32(owner, t * 4) == 0 then
		return t
	end
	local W, H = self.W, self.H
	local cx = t % W
	local cy = t // W
	for rr = 1, r do
		for dy = -rr, rr do
			local y = cy + dy
			if y < 0 or y >= H then
				continue
			end
			for dx = -rr, rr do
				if math.max(math.abs(dx), math.abs(dy)) ~= rr then
					continue
				end
				local x = cx + dx
				if x < 0 or x >= W then
					continue
				end
				local c = y * W + x
				if self:claimable(c) and readi32(owner, c * 4) == 0 then
					return c
				end
			end
		end
	end
	return -1
end

--- Claims the unowned claimable tiles of the spawn disk (_spawn_disk); returns the
--- tiles claimed (1-based).
function Sim._claim_disk(self: any, id: number, center: number, radius: number): { number }
	local owner = self.owner
	local out = {}
	for _, c in self:_spawn_disk(center, radius) do
		if readi32(owner, c * 4) == 0 and self:claimable(c) then
			self:set_owner(c, id)
			table.insert(out, c)
		end
	end
	return out
end

function Sim._spawn_owner(self: any, id: number, t: number, radius: number): { number }
	local got = self:_claim_disk(id, t, radius)
	self.o_spawned[id] = 1
	self.o_spawn_tile[id] = t
	self:ev({ Ev.SPAWNED, id, t })
	return got
end

-- =============================================================================================
-- Intents
-- =============================================================================================

function Sim._process_intents(self: any)
	if #self._intents == 0 then
		return
	end
	local list = self._intents
	self._intents = {}
	for _, e in list do
		local id = e[1]
		if type(id) ~= "number" or id <= 0 or id > self.owner_total then
			continue
		end
		local it = e[2]
		if type(it) ~= "table" then
			continue
		end
		self:_apply_intent(id, it)
	end
end

--- Typed, finite reads from untrusted intent dictionaries (wrong types or NaN → default).
local function _num(it: { [string]: any }, key: string, default: number): number
	local v = it[key]
	if type(v) ~= "number" or not Defs.is_finite(v) then
		return default
	end
	return v
end
Sim._num = _num

local function _int(it: { [string]: any }, key: string, default: number): number
	local v = it[key]
	if type(v) == "number" and Defs.is_finite(v) then
		return Defs.trunc(v)
	end
	return default
end
Sim._int = _int

local function _str(it: { [string]: any }, key: string): string
	local v = it[key]
	return if type(v) == "string" then v else ""
end
Sim._str = _str

--- The most levels / bombs one intent can ask for (Protocol caps the wire).
Sim.MAX_INTENT_AMOUNT = 50

function Sim._apply_intent(self: any, id: number, it: { [string]: any })
	local kind = _str(it, "type")
	local tile = _int(it, "tile", -1)
	if kind == "spawn" then
		self:_intent_spawn(id, tile)
		return
	end
	if self.phase ~= Defs.PHASE_PLAYING or self.o_alive[id] == 0 or self.o_spawned[id] == 0 then
		return
	end
	if kind == "attack" then
		self:intent_attack(id, tile, _num(it, "ratio", Rules.DEFAULT_ATTACK_RATIO))
	elseif kind == "boat" then
		self:launch_boat(id, tile, _num(it, "ratio", Rules.DEFAULT_ATTACK_RATIO))
	elseif kind == "build" then
		-- `amount`: a bulk upgrade (level after level, each at the
		-- next price, until one can't be afforded); only ever more than one level on an existing
		-- structure
		local kname = _str(it, "kind")
		local ok, upgraded = self:try_build(id, kname, tile)
		local n = math.clamp(_int(it, "amount", 1), 1, Sim.MAX_INTENT_AMOUNT)
		for _ = 2, n do
			if not ok or not upgraded then
				break
			end
			ok, upgraded = self:try_build(id, kname, tile)
		end
	elseif kind == "nuke" then
		-- `amount`: stacked atom bombs (several at one target, each from a loaded silo)
		local kname = _str(it, "kind")
		local n = if kname == "atom" then math.clamp(_int(it, "amount", 1), 1, Sim.MAX_INTENT_AMOUNT) else 1
		for _ = 1, n do
			if not self:launch_nuke(id, kname, tile) then
				break
			end
		end
	elseif kind == "retreat" then
		self:retreat(id, _int(it, "attack_id", 0))
	elseif kind == "move_warship" then
		self:move_warship(id, _int(it, "uid", 0), tile)
	elseif kind == "ally_request" then
		self:ally_request(id, _int(it, "target", 0))
	elseif kind == "ally_reply" then
		self:ally_reply(id, _int(it, "target", 0), it.accept == true)
	elseif kind == "ally_break" then
		self:ally_break(id, _int(it, "target", 0))
	elseif kind == "ally_extend" then
		self:ally_extend(id, _int(it, "target", 0))
	elseif kind == "donate" then
		self:donate(id, _int(it, "target", 0), _int(it, "troops", 0))
	elseif kind == "reinforce" then
		self:reinforce(id)
	elseif kind == "callarms" then
		self:call_to_arms(id)
	elseif kind == "demolish" then
		self:demolish(id, tile)
	elseif kind == "tax" then
		self:set_tax(id, _str(it, "kind"))
	elseif kind == "war" then
		local tg = _int(it, "target", 0)
		if tg > 0 and tg <= self.owner_total and self.wars ~= nil and not self:allied(id, tg) then
			self:may_attack(id, tg)
		end
	elseif kind == "peace" then
		local tg = _int(it, "target", 0)
		if tg > 0 and tg <= self.owner_total then
			self:offer_peace(id, tg, _str(it, "kind"))
		end
	elseif kind == "army" then
		-- (a depth match's armies: kind raise {troops} | disband {uid} | attack / advance / hold {uid, target} |
		-- march {uid, tile}, SimArmies)
		local k = _str(it, "kind")
		local uid = _int(it, "uid", 0)
		if k == "raise" then
			self:raise_army(id, math.max(_int(it, "troops", 0), 0))
		elseif k == "disband" then
			self:disband_army(id, uid)
		elseif k == "march" then
			self:army_march(id, uid, tile)
		elseif k == "attack" or k == "advance" or k == "hold" then
			self:army_front(id, uid, _int(it, "target", 0), k)
		end
	elseif kind == "peace_reply" then
		local tg = _int(it, "target", 0)
		if tg > 0 and tg <= self.owner_total then
			self:peace_reply(id, tg, it.accept == true)
		end
	elseif kind == "doctrine" then
		self:doctrine_choose(id, _str(it, "kind"))
	elseif kind == "edict" then
		self:edict_use(id, _str(it, "kind"))
	end
end

function Sim._set_pending(self: any, id: number, t: number)
	if self._pending_spawn[id] == nil then
		table.insert(self._pending_order, id)
	end
	self._pending_spawn[id] = t
end

--- No banner within this many full-size tiles of another ruler's (players and bot players), nor of a landmark (playtest
--- 2026-11-08: planting right on another player to kill them as they start, and on a landmark, were how a match was won
--- before it began). Scaled with the map.
Sim.SPAWN_KEEP_RULER = 40
Sim.SPAWN_KEEP_LANDMARK = 20

--- Why `t` is no place for `id`'s banner (a message), or nil when it is.
function Sim.spawn_blocked(self: any, id: number, t: number): string?
	local W = self.W
	local sc = tonumber(self.map.scale) or 1
	local tx, ty = t % W, t // W
	local kr = Sim.SPAWN_KEEP_RULER * sc
	for o = 1, self.owner_total do
		if o ~= id and self.o_kind[o] == Defs.KIND_HUMAN and self.o_alive[o] == 1 then
			local at = if self.o_spawned[o] == 1 then self.o_spawn_tile[o] else (self._pending_spawn[o] or -1)
			if at >= 0 then
				local dx, dy = at % W - tx, at // W - ty
				if dx * dx + dy * dy < kr * kr then
					return "Too close to another ruler's banner: plant it farther off"
				end
			end
		end
	end
	local kl = Sim.SPAWN_KEEP_LANDMARK * sc
	for _, site in self.landmark_sites or {} do
		local dx, dy = site.tile % W - tx, site.tile // W - ty
		if dx * dx + dy * dy < kl * kl then
			return "Too close to a landmark: plant your banner farther off"
		end
	end
	return nil
end

function Sim._intent_spawn(self: any, id: number, t: number): boolean
	if
		id <= 0
		or id > self.owner_total
		or self.o_kind[id] ~= Defs.KIND_HUMAN
		or self.o_alive[id] == 0
		or self.o_left[id] == 1
	then
		return false
	end
	if t < 0 or t >= self.N or t ~= t or not self:claimable(t) then
		return false
	end
	local owner = self.owner
	-- (not on another ruler's banner, nor on a landmark: Sim.spawn_blocked)
	local why = self:spawn_blocked(id, t)
	if why ~= nil then
		self:msg(id, Defs.MSG_INFO, why)
		return false
	end
	if self.phase == Defs.PHASE_SPAWN then
		local o = readi32(owner, t * 4)
		if o ~= 0 and o ~= id then
			return false
		end
		local disk = self._human_disk[id]
		if disk ~= nil then
			for _, c in disk do
				if readi32(owner, c * 4) == id then
					self:set_owner(c, 0)
				end
			end
			self._human_disk[id] = nil
		end
		self.o_spawned[id] = 0
		self:_recolor_human(id, t)
		self:_set_pending(id, t)
		self.o_troops[id] = self:_start_troops_of(id)
		if self.solo and self.spawn_left < 0 then
			self.spawn_left = self.solo_countdown
			self:ev({ Ev.PHASE, Defs.PHASE_SPAWN, self.spawn_left })
		end
		return true
	end
	if
		self.phase == Defs.PHASE_PLAYING
		and self.o_spawned[id] == 0
		and readi32(owner, t * 4) == 0
		and self._pending_spawn[id] == nil
	then
		self:_recolor_human(id, t)
		self:_set_pending(id, t)
		self.o_troops[id] =
			math.max(Rules.START_TROOPS_HUMAN * 0.5, self:_median_nation_troops() * Rules.LATE_JOIN_TROOP_FRACTION)
		self.o_gold[id] = Rules.START_GOLD
		return true
	end
	return false
end

function Sim._claim_pending_spawns(self: any)
	if #self._pending_order == 0 then
		return
	end
	local owner = self.owner
	for _, id in self._pending_order do
		local t = self._pending_spawn[id]
		if t == nil or self.o_alive[id] == 0 or self.o_left[id] == 1 then
			continue
		end
		if readi32(owner, t * 4) ~= 0 or not self:claimable(t) then
			t = self:_nearest_free_land(t, math.ceil(6 * self.R.LEGACY_LIN))
		end
		if t < 0 then
			self:msg(id, Defs.MSG_INFO, "Someone landed there first. Choose again")
			continue
		end
		self._human_disk[id] = self:_spawn_owner(id, t, self.R.SPAWN_RADIUS)
		if self.phase == Defs.PHASE_PLAYING and not self.solo then
			-- (one placed when the spawn phase ended, or a late joiner: from its first tick in play)
			self.o_shield_until[id] = self.tick + Rules.SPAWN_SHIELD_TICKS
		end
		if self._auto_placed[id] then
			self._auto_placed[id] = nil
			self:msg(id, Defs.MSG_GOOD, "You didn't choose, so your banner was planted here.")
		elseif self.phase == Defs.PHASE_PLAYING then
			self:msg(
				id,
				Defs.MSG_GOOD,
				if self:shielded(id)
					then string.format(
						"Your banner stands. Spread from here. Nobody can touch you for %d s",
						Rules.SPAWN_SHIELD_TICKS // TICK_RATE
					)
					else "Your banner stands. Spread from here."
			)
		end
	end
	table.clear(self._pending_spawn)
	table.clear(self._pending_order)
	self._force_stats = true
end

--- Naval hooks → AI (the nations' warship behaviour).
function Sim._on_transport_sunk(self: any, u: any, killer: number)
	self.ai:on_transport_sunk(self, u, killer)
end

function Sim._on_trade_captured(self: any, victim: number, captor: number, t: number)
	self.ai:on_trade_captured(self, victim, captor, t)
end

function Sim._on_transport_launched(self: any, u: any, target_owner: number)
	self.ai:on_transport_launched(self, u, target_owner)
end

--- No transport lands on a person under their spawn shield; AI transports may only open a new war
--- on a human within the AI's human-protection rules.
function Sim._landing_allowed(self: any, id: number, tg: number): boolean
	if self:shielded(tg) then
		return false
	end
	if self.o_ai[id] == 0 or not self:is_human(tg) or self:attack_between(id, tg) ~= nil then
		return true
	end
	return self.ai:may_attack_human(self, id, tg)
end

--- Picks human `id`'s colour for a start at `t` (see SimColors.for_human). A changed colour is
--- announced by re-sending OWNER_ADD (the mirror updates the entry in place).
function Sim._recolor_human(self: any, id: number, t: number)
	if self.team_mode and self.o_team[id] ~= 0 then
		-- (a team game: the team's colour stays)
		return
	end
	self:set_owner_color(id, SimColors.for_human(self, id, t, Sim.COLOR_NEAR_HUMAN))
end

-- =============================================================================================
-- Teams (team games; Core/Teams)
-- =============================================================================================

--- Bot players' random starts tried for one near a teammate (see Teams).
Sim.TEAM_START_TRIES = 32
--- A teammate starts about this share of the map's width from the nearest teammate (TEAM_MATE_MIN tiles at least).
Sim.TEAM_MATE_GAP = 0.045
Sim.TEAM_MATE_MIN = 40
--- A team's first start: random starts tried for the one farthest from the other teams'.
Sim.TEAM_FIRST_TRIES = 32
--- The map's top and bottom rows by this share count as the poles: a team's first start avoids them (playtest
--- 2026-11-08: three teams of four began in Antarctica).
Sim.TEAM_POLAR = 0.14

--- Puts `id` on team `t` and gives it the team's next shade (re-sends OWNER_ADD with the team).
function Sim._set_team(self: any, id: number, t: number)
	local n = self._team_n[t] or 0
	self._team_n[t] = n + 1
	self.o_team[id] = t
	self.o_color[id] = Teams.color(self.team_names[t] or "", t, n)
	self:ev({ Ev.OWNER_ADD, id, self.o_name[id], self.o_color[id], self.o_kind[id], t })
end

--- A team game: every player onto a team, once, after the humans and the bot players are in (the
--- humans in join order, the bot players filling the places left; Humans Vs Nations: the humans and
--- bot players against the nations). `groups`: human id → the key of the party it joined with.
function Sim.assign_teams(self: any, groups: { [number]: string }?)
	if not self.team_mode or #self.team_names > 0 then
		return
	end
	local cfg = self.team_config
	if cfg == Teams.HVN then
		self.team_names = Teams.resolve(cfg, 0)
		for _, h in self.humans do
			self:_set_team(h, 1)
		end
		for id = 1, self.owner_total do
			if self.o_kind[id] == Defs.KIND_NATION then
				self:_set_team(id, 2)
			end
		end
		return
	end
	local players = {}
	for _, h in self.humans do
		table.insert(players, { id = h, group = if groups then groups[h] else nil, filler = self.o_bot[h] == 1 })
	end
	-- (nations, when a team game has them, fill like bot players, after all humans)
	for id = 1, self.owner_total do
		if self.o_kind[id] == Defs.KIND_NATION then
			table.insert(players, { id = id, filler = true })
		end
	end
	self.team_names = Teams.resolve(cfg, #players)
	local rng = self.rng
	local out = Teams.assign(players, #self.team_names, Teams.packs(cfg), function(list)
		for i = #list, 2, -1 do
			local j = rng:randi_range(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end)
	for _, p in players do
		self:_set_team(p.id, out[p.id])
	end
end

--- A team game: a human who came after the teams were made joins a teammate of `group` (players it
--- came with) if one has a team, else the team with the fewest players.
function Sim.join_team(self: any, id: number, group: { number }?)
	if not self.team_mode or #self.team_names == 0 or self.o_team[id] ~= 0 then
		return
	end
	if self.team_config == Teams.HVN then
		self:_set_team(id, 1)
		return
	end
	for _, m in group or {} do
		if m ~= id and self.o_team[m] ~= 0 then
			self:_set_team(id, self.o_team[m])
			return
		end
	end
	local count = table.create(#self.team_names, 0)
	for _, h in self.humans do
		local t = self.o_team[h]
		if t ~= 0 and self.o_alive[h] == 1 then
			count[t] += 1
		end
	end
	local best = 1
	for t = 2, #self.team_names do
		if count[t] < count[best] then
			best = t
		end
	end
	self:_set_team(id, best)
end

--- Team games: a bot player's start, the nearest to a teammate already on the map of a few
--- random starts. With no teammate there yet, the team's ground is chosen: of TEAM_FIRST_TRIES random starts, the
--- one farthest from the other teams' starts, away from the poles (teams spread over the map, each kept together).
function Sim._team_start(self: any, id: number): number
	local mates, foes = {}, {}
	for o = 1, self.owner_total do
		-- (a start already chosen but not yet landed counts too: two teams choosing on one tick saw neither)
		local at = if self.o_spawned[o] == 1 then self.o_spawn_tile[o] else (self._pending_spawn[o] or -1)
		if o ~= id and at >= 0 then
			if self:same_team(id, o) then
				table.insert(mates, at)
			elseif self.o_team[o] ~= 0 then
				table.insert(foes, at)
			end
		end
	end
	local geo_manhattan = self.geo_manhattan
	if #mates == 0 then
		local W, H = self.W, self.H
		local lo, hi = H * Sim.TEAM_POLAR, H * (1 - Sim.TEAM_POLAR)
		local best, bs = -1, -1
		for _ = 1, Sim.TEAM_FIRST_TRIES do
			local c = self:_random_start(id)
			if c < 0 then
				break
			end
			local d = math.huge
			for _, f in foes do
				d = math.min(d, geo_manhattan(f, c))
			end
			if d == math.huge then
				d = 1
			end
			local y = c // W
			local sc = if y < lo or y >= hi then d * 0.25 else d
			if sc > bs then
				best, bs = c, sc
			end
		end
		return best
	end
	-- a teammate's start: about TEAM_MATE_GAP of the map's width from the nearest teammate, not on top of them (playtest
	-- 2026-11-08: packed together, one bot's land walled another's in), never farther than twice that
	local gap = math.max(Sim.TEAM_MATE_MIN, self.W * Sim.TEAM_MATE_GAP)
	local best, bs = -1, math.huge
	for _ = 1, Sim.TEAM_START_TRIES do
		local c = self:_random_start(id)
		if c < 0 then
			break
		end
		local d = math.huge
		for _, m in mates do
			d = math.min(d, geo_manhattan(m, c))
		end
		local sc = math.abs(d - gap)
		if d > 2 * gap then
			sc += d
		end
		-- (and off the poles, like the team's first start)
		local y = c // self.W
		if y < self.H * Sim.TEAM_POLAR or y >= self.H * (1 - Sim.TEAM_POLAR) then
			sc += 2 * gap
		end
		if sc < bs then
			best, bs = c, sc
		end
	end
	return best
end

--- Team games: tiles held per team (alive owners; 1-based by team).
function Sim.team_tiles(self: any): { number }
	local sums = table.create(#self.team_names, 0)
	for id = 1, self.owner_total do
		local t = self.o_team[id]
		if t ~= 0 and self.o_alive[id] == 1 then
			sums[t] += self.o_tiles[id]
		end
	end
	return sums
end

function Sim._median_nation_troops(self: any): number
	local vals = {}
	for id = 1, self.owner_total do
		if self.o_kind[id] == Defs.KIND_NATION and self.o_alive[id] == 1 then
			table.insert(vals, self.o_troops[id])
		end
	end
	if #vals == 0 then
		return Rules.start_troops(Defs.KIND_NATION, self.difficulty)
	end
	table.sort(vals)
	return vals[#vals // 2 + 1]
end

--- Attack intent (also used by the AI). True when troops were committed.
function Sim.intent_attack(self: any, id: number, t: number, ratio: number): boolean
	if not Defs.is_finite(ratio) then
		return false
	end
	-- The client sends a ratio: that share of current troops attacks.
	return self:intent_attack_troops(id, t, self.o_troops[id] * math.clamp(ratio, 0.01, 1.0))
end

--- An attack with `amount` troops (as the AI sends it).
--- True when troops were committed.
function Sim.intent_attack_troops(self: any, id: number, t: number, amount: number): boolean
	if t < 0 or t >= self.N or buffer.readu8(self.land, t) == 0 or not Defs.is_finite(amount) then
		return false
	end
	local tg = readi32(self.owner, t * 4)
	if tg == id then
		return false
	end
	if tg ~= 0 and self:allied(id, tg) then
		self:msg(id, Defs.MSG_INFO, self.o_name[tg] .. " is under your oath. Break it first.")
		return false
	end
	if tg ~= 0 and self.o_alive[tg] == 0 then
		return false
	end
	if self:shielded(tg) then
		self:msg(id, Defs.MSG_INFO, self:shield_text(tg))
		return false
	end
	-- (a depth match: a war is declared, or a truce or vassalage forbids it, SimDiplomacy)
	if tg ~= 0 and self.wars ~= nil and not self:may_attack(id, tg) then
		return false
	end
	local o_troops = self.o_troops
	-- An attack takes min(amount, home troops), floored (troops are whole numbers).
	local home = o_troops[id]
	local troops = math.floor(math.min(amount, home))
	if troops < 1.0 then
		return false
	end
	o_troops[id] -= troops
	self.dbg_flow[id * 5] += troops
	local a = self:start_attack(id, tg, troops, -1)
	if a == nil and o_troops[id] >= home - 0.5 then
		-- Refunded: there is no frontier (troops spent cancelling a counter-attack are not refunded).
		if tg ~= 0 then
			self:msg(id, Defs.MSG_INFO, "No land route to " .. self.o_name[tg] .. ". Order a landing")
		else
			self:msg(id, Defs.MSG_INFO, "Nothing of yours touches it. Try a landing.")
		end
		return false
	end
	return true
end

--- `loser` surrenders every tile to `winner` (AI endgame capitulation). The loser is eliminated
--- at the end of the tick with `winner` as the conqueror; its gold goes along.
function Sim.capitulate(self: any, loser: number, winner: number)
	if loser <= 0 or winner <= 0 or self.o_alive[loser] == 0 or self.o_alive[winner] == 0 or self:is_human(loser) then
		return
	end
	local owner = self.owner
	local tiles = {}
	local map = self.map
	local land_list = map.land_list
	for k = 0, map.land_count - 1 do
		local c = readi32(land_list, k * 4)
		if readi32(owner, c * 4) == loser then
			table.insert(tiles, c)
		end
	end
	for _, c in tiles do
		self:conquer(c, winner, nil)
	end
	self.last_capitulation = self.tick
	self.o_killer[loser] = winner
	local top = self:top_owners()
	for _, h in self.humans do
		if self.o_left[h] == 0 and self:news_relevant(h, loser, winner, top) then
			self:msg(h, Defs.MSG_INFO, self.o_name[loser] .. " bent the knee to " .. self.o_name[winner])
		end
	end
end

--- Alliance request: an answer to a pending request
--- from `target` accepts it; otherwise a new request, unless one is pending or the previous request
--- to `target` was made less than ALLY_REQUEST_COOLDOWN_TICKS ago.
function Sim.ally_request(self: any, id: number, target: number): boolean
	if self.no_alliances then
		return false
	end
	-- (a depth match: no pact with a realm you are at war with; make peace first)
	if self.wars ~= nil and target > 0 and self:at_war(id, target) then
		self:msg(id, Defs.MSG_INFO, "You are at war with them: make peace first")
		return false
	end
	if target <= 0 or target > self.owner_total or target == id or self.o_alive[target] == 0 then
		return false
	end
	if self:allied(id, target) or self:has_request(id, target) then
		return false
	end
	if self:has_request(target, id) then
		self:close_request(target, id)
		self:form_alliance(target, id)
		return true
	end
	local wait = self:request_cooldown_left(id, target)
	if wait > 0 then
		self:msg(
			id,
			Defs.MSG_INFO,
			string.format("%s will not hear you for another %d s", self.o_name[target], math.ceil(wait / TICK_RATE))
		)
		return false
	end
	self:add_request(id, target)
	if self.o_ai[target] == 1 then
		self.ai:queue_reply(self, id, target)
	end
	return true
end

function Sim.ally_reply(self: any, id: number, target: number, accept: boolean): boolean
	if target <= 0 or target > self.owner_total or not self:has_request(target, id) then
		return false
	end
	if accept and self.o_alive[target] == 1 then
		self:close_request(target, id)
		self:form_alliance(target, id)
	else
		self:close_request(target, id)
		self:msg(target, Defs.MSG_INFO, self.o_name[id] .. " wants no pact with you")
	end
	return true
end

--- Alliance renewal: `id` asks to renew its alliance with `target` (in the last
--- ALLIANCE_EXTEND_WINDOW_TICKS before it expires). Renewed once both asked; an AI ally answers a
--- request (SimAI.queue_extension). True when accepted.
function Sim.ally_extend(self: any, id: number, target: number): boolean
	if target <= 0 or target > self.owner_total then
		return false
	end
	local r = self:extend_alliance(id, target)
	if r == "asked" and self.o_ai[target] == 1 then
		self.ai:queue_extension(self, id, target)
	end
	return r ~= ""
end

function Sim.ally_break(self: any, id: number, target: number): boolean
	if not self:has_alliance(id, target) then
		return false
	end
	self:end_alliance(id, target, id)
	return true
end

function Sim.donate(self: any, id: number, target: number, troops: number): boolean
	if target <= 0 or target > self.owner_total or not self:allied(id, target) or self.o_alive[target] == 0 then
		return false
	end
	local amount = math.clamp(troops, 0.0, math.max(self.o_troops[id], 0.0))
	if amount < 1.0 then
		return false
	end
	self.o_troops[id] -= amount
	self.o_troops[target] += amount
	self:msg(target, Defs.MSG_GOOD, NumberFormat.render_troops(amount) .. " troops arrive from " .. self.o_name[id])
	return true
end

-- =============================================================================================
-- Phases
-- =============================================================================================

function Sim._spawn_phase_tick(self: any)
	if self.spawn_left < 0 then
		return
	end
	self.spawn_left -= 1
	if self.spawn_left > 0 then
		if self.spawn_left % 10 == 0 then
			self:ev({ Ev.PHASE, Defs.PHASE_SPAWN, self.spawn_left })
		end
		for id, at in self._bot_spawn_at do
			if self.spawn_left <= at then
				self._bot_spawn_at[id] = nil
				if self.o_spawned[id] == 0 and self.o_alive[id] == 1 and self._pending_spawn[id] == nil then
					local t = if self.team_mode then self:_team_start(id) else self:_random_start(id)
					if t >= 0 then
						self:_recolor_human(id, t)
						self:_set_pending(id, t)
					end
				end
			end
		end
		return
	end
	-- Humans that never picked get a random start (multiplayer).
	for _, h in self.humans do
		if self.o_spawned[h] == 0 and self.o_alive[h] == 1 and self.o_left[h] == 0 then
			local t = if self.team_mode then self:_team_start(h) else self:_random_start(h)
			if t >= 0 then
				self:_recolor_human(h, t)
				self:_set_pending(h, t)
				self._auto_placed[h] = true
			end
		end
	end
	self:_start_playing()
end

function Sim._start_playing(self: any)
	self.phase = Defs.PHASE_PLAYING
	self.playing_since = self.tick
	self.spawn_left = 0
	table.clear(self.pending_out)
	self:recount_provinces()
	if self.time_limit_s > 0 and (not self.solo or self.solo_clock) then
		self.time_limit_ticks = self.tick + self.time_limit_s * TICK_RATE
	end
	self:ev({ Ev.PHASE, Defs.PHASE_PLAYING, 0 })
	for id = 1, self.owner_total do
		if self.o_alive[id] == 1 and self.o_spawned[id] == 1 then
			if self.o_kind[id] == Defs.KIND_HUMAN and not self.solo then
				self.o_shield_until[id] = self.tick + Rules.SPAWN_SHIELD_TICKS
			end
			local tkind, tdiff = self:troop_rules_of(id)
			self.o_cap[id] = self:_cap_of(id, self.R.max_troops(tkind, self:eff_tiles(id), 0, tdiff))
			self.o_income[id] = self:_income_of(id, Rules.passive_income(self.o_kind[id], if self.prov ~= nil then self:eff_tiles(id) else self.o_tiles[id]))
		end
	end
end

function Sim._economy_tick(self: any)
	local tick = self.tick
	local second = tick % 10 == 0
	local difficulty = self.difficulty
	local o_alive = self.o_alive
	local o_spawned = self.o_spawned
	local o_kind = self.o_kind
	local o_tiles = self.o_tiles
	local o_cap = self.o_cap
	local o_troops = self.o_troops
	local o_income = self.o_income
	local o_gold = self.o_gold
	local o_alevel = self.o_alevel
	local o_bonus_rate = self.o_bonus_rate
	local o_bonus_acc = self.o_bonus_acc
	local max_troops = self.R.max_troops
	local troop_growth_applied = Rules.troop_growth_applied
	local o_levy_until = self.o_levy_until
	local o_bot = self.o_bot
	local o_skill = self.o_skill
	local NOVICE = Sim.NOVICE_SKILL
	self:_crown_tick()
	if self.phase ~= Defs.PHASE_PLAYING then
		return
	end
	if self.doctrines_on then
		self:_doctrines_tick()
		if self.rivals_on then
			self:_rivals_tick()
		end
	end
	local mults = self.mults_on
	if mults and second then
		if self.events_on then
			self:_world_events_tick()
		end
		if self.o_tax ~= nil then
			self:_rulers_second()
			self:_economy_depth_second()
			self:_diplomacy_second()
			self:_armies_second()
			self:_ai_armies_second()
			self:_ambitions_second()
			self:_realm_rows_second()
		end
		self:_refresh_mults()
	end
	local m_cap, m_gold, m_regen = self.m_cap, self.m_gold, self.m_regen
	for id = 1, self.owner_total do
		if o_alive[id] == 0 or o_spawned[id] == 0 then
			continue
		end
		local kind = o_kind[id]
		-- (bot players count as nations for troops, novices as Easy ones: troop_rules_of; gold stays a player's)
		local tkind, tdiff = kind, difficulty
		if o_bot[id] == 1 then
			tkind, tdiff = Defs.KIND_NATION, if o_skill[id] == NOVICE then NOVICE else difficulty
		end
		-- maxTroops: + cityTroopIncrease per level of each finished city.
		-- (frozen waste counts half: Rules.frozen_from)
		-- (a depth match: the land by its provinces, SimProvinces.eff_tiles; else raw tiles, frozen waste at half)
		local land = self:eff_tiles(id)
		local cap = max_troops(tkind, land, o_alevel[id * STRUCT_KINDS + Defs.S_CITY], tdiff)
		if mults then
			local mc = m_cap[id]
			-- (a multiplier of 1 leaves the cap as the rules give it, unrounded: matches with only a few historical
			-- strengths keep everyone else's numbers exactly; Data/Traits)
			if mc ~= nil and mc ~= 1 then
				cap = math.floor(cap * mc)
			end
		end
		o_cap[id] = cap
		-- Per-tick player update: + troopIncreaseRate troops (whole troops: truncated) and
		-- + goldAdditionRate gold every tick, never during the spawn phase.
		local grown = troop_growth_applied(tkind, o_troops[id], cap, tdiff)
		-- (a Harvest Levy empties the fields for a while: SimArsenal.reinforce)
		if o_levy_until[id] > tick then
			grown = 0
		end
		if mults and grown > 0 then
			local mr = m_regen[id]
			if mr ~= nil and mr ~= 1.0 then
				grown = math.min(math.floor(grown * mr), math.max(cap - o_troops[id], 0))
			end
		end
		-- (a depth match: regrowth draws on manpower, SimEconomy)
		if grown > 0 and self.o_mp ~= nil then
			grown = self:_draw_manpower(id, grown)
		end
		o_troops[id] += grown
		if (tick + id) % 10 == 0 then
			-- (a depth match: the provinces' taxes and the markets on top, SimEconomy.o_ptax)
			local base = Rules.passive_income(kind, if self.prov ~= nil then land else o_tiles[id])
			if self.o_ptax ~= nil then
				base += self.o_ptax[id] / math.max(self.dp.tax_gold[self.o_tax[id]], 0.01)
			end
			o_income[id] = base * (if mults then (m_gold[id] or 1.0) else 1.0)
		end
		o_gold[id] += o_income[id] / TICK_RATE
		if second then
			o_bonus_rate[id] = o_bonus_rate[id] * 0.9 + o_bonus_acc[id] * 0.1
			o_bonus_acc[id] = 0.0
		end
	end
end

function Sim._diplomacy_tick(self: any)
	local tick = self.tick
	-- (alliance and request expiry: SimState._alliances_tick, every tick)
	if tick % 600 == 0 and next(self.grudge) ~= nil then
		local stale = {}
		for k, v in self.grudge do
			if v <= tick then
				table.insert(stale, k)
			end
		end
		for _, k in stale do
			self.grudge[k] = nil
		end
	end
end

function Sim._process_eliminations(self: any)
	if #self.pending_out == 0 then
		return
	end
	local list = self.pending_out
	self.pending_out = {}
	for _, id in list do
		if self.o_alive[id] == 1 and self.o_spawned[id] == 1 and self.o_tiles[id] <= 0 then
			self:_eliminate(id, self.o_killer[id])
		end
	end
end

function Sim._eliminate(self: any, id: number, killer: number)
	-- Decide who hears about it before alliances are dissolved: humans involved, allied or
	-- bordering, or when a top-5 owner did the conquering. Tribes are never world news.
	local audience = {}
	if #self.humans > 0 then
		local top = self:top_owners()
		for _, h in self.humans do
			if h == id or h == killer or self.o_alive[h] == 0 or self.o_left[h] == 1 then
				continue
			end
			if self.o_kind[id] == Defs.KIND_TRIBE and not self:allied(h, id) and not self:allied(h, killer) then
				continue
			end
			if self:news_relevant(h, id, killer, top) then
				table.insert(audience, h)
			end
		end
	end
	self.o_alive[id] = 0
	self.o_troops[id] = 0.0
	self:ev({ Ev.OWNER_OUT, id, killer })
	if self.wars ~= nil then
		self:_diplomacy_eliminated(id)
	end
	self:end_attacks_of(id)
	self:remove_units_of(id)
	for _, a in self:allies_of(id) do
		self:end_alliance(id, a, 0)
	end
	local reqs = {}
	for _, k in self:_ordered_keys(self.requests) do
		if k // 1024 == id or k % 1024 == id then
			table.insert(reqs, k)
		end
	end
	for _, k in reqs do
		self:close_request(k // 1024, k % 1024)
	end
	for kind = 0, STRUCT_KINDS - 1 do
		if self.o_scount[id * STRUCT_KINDS + kind] > 0 then
			for _, s in self:structs_of(id, kind) do
				self:destroy_struct(s)
			end
		end
	end
	local o_name = self.o_name
	if killer > 0 then
		self:_conquest_gold(id, killer)
		self:msg(killer, Defs.MSG_GOOD, o_name[id] .. " falls by your hand")
	end
	if self:is_human(id) then
		if killer > 0 then
			self:msg(id, Defs.MSG_BAD, o_name[killer] .. " has the last of your land")
		else
			self:msg(id, Defs.MSG_BAD, "Your banner is down")
		end
	end
	for _, h in audience do
		self:msg(
			h,
			Defs.MSG_INFO,
			o_name[id] .. " has fallen" .. (if killer > 0 then " to " .. o_name[killer] else "")
		)
	end
	self:_rivals_eliminated(id, killer)
end

--- Conquest: `by` takes `victim`'s gold (conquerGoldAmount: half of a human's) and
--- Ev.CONQUEST tells the clients (the conqueror's "+ gold" popup), once per victim: gold earned
--- by pockets left after an annexation still goes to the final conqueror, silently.
--- A fallen realm's treasury (Rules.conquer_gold of its gold) is shared out by the land each living owner took from it
--- in the war (playtest 2026-11-08: whoever took the last tile took it all, after others had done the fighting). `by`,
--- who finished it, gets the whole when nobody's share is on record. Each taker sees its share (Ev.CONQUEST).
function Sim._conquest_gold(self: any, victim: number, by: number)
	local pot = Rules.conquer_gold(self.o_kind[victim], self.o_gold[victim])
	self.o_gold[victim] = 0.0
	local took = self._took[victim]
	self._took[victim] = nil
	local shares = {}
	local total = 0
	if took ~= nil then
		for id, n in took do
			if id ~= victim and n > 0 and self.o_alive[id] == 1 and self.o_kind[id] ~= Defs.KIND_TRIBE then
				table.insert(shares, id)
				total += n
			end
		end
	end
	if total <= 0 then
		shares = { by }
		took = { [by] = 1 }
		total = 1
	end
	-- (in id order: every copy of the Sim pays out the same way)
	table.sort(shares)
	for _, id in shares do
		local gold = pot * took[id] / total
		if self.mults_on then
			gold *= self.m_conq[id] or 1.0
		end
		self.o_gold[id] += gold
		if not self._conquest_sent[victim * 1024 + id] then
			self._conquest_sent[victim * 1024 + id] = true
			self:ev({ Ev.CONQUEST, id, victim, math.floor(gold) })
		end
	end
end

function Sim._check_victory(self: any)
	local best = 0
	local bt = -1
	local o_alive = self.o_alive
	local o_tiles = self.o_tiles
	for id = 1, self.owner_total do
		if o_alive[id] == 1 and o_tiles[id] > bt then
			bt = o_tiles[id]
			best = id
		end
	end
	-- A team game: the team's land together; tribes are
	-- on no team and never win. `best` is then the winning team's biggest member.
	local team = 0
	if self.team_mode and #self.team_names > 0 then
		local sums = self:team_tiles()
		local tt = -1
		for t = 1, #sums do
			if sums[t] > tt then
				team, tt = t, sums[t]
			end
		end
		bt = -1
		best = 0
		for id = 1, self.owner_total do
			if o_alive[id] == 1 and self.o_team[id] == team and o_tiles[id] > bt then
				bt, best = o_tiles[id], id
			end
		end
		bt = tt
	end
	if best > 0 and bt >= (self.win_share or Rules.WIN_SHARE) * (self.map.contestable_count - self.fallout_count) then
		self:_game_over(best, Defs.OVER_DOMINATION, team)
		return
	end
	if self.time_limit_ticks > 0 and self.tick >= self.time_limit_ticks then
		-- (a depth match without a conqueror: the most prestige wins, SimAmbitions)
		if self.o_amb ~= nil and team == 0 then
			local leader = self:prestige_leader()
			if leader > 0 then
				self:_game_over(leader, Defs.OVER_PRESTIGE, 0)
				return
			end
		end
		self:_game_over(best, Defs.OVER_TIME, team)
		return
	end
	-- Solo never ends on the human's death: they may keep watching (only domination ends it).
	-- Multiplayer ends once every human that spawned is out (or every survivor has left).
	if self.max_humans > 0 and not self.solo and #self.humans > 0 then
		local any_spawned = false
		local any_present = false
		local any_alive = false
		for _, h in self.humans do
			if self.o_spawned[h] == 1 then
				any_spawned = true
				if o_alive[h] == 1 then
					any_alive = true
					if self.o_left[h] == 0 then
						any_present = true
					end
				end
			end
		end
		if any_spawned and not any_alive then
			self:_game_over(best, Defs.OVER_DEFEATED, team)
		elseif any_spawned and not any_present then
			self:_game_over(best, Defs.OVER_ABANDONED, team)
		end
	end
end

function Sim._game_over(self: any, w: number, reason: number, team: number?)
	self.phase = Defs.PHASE_OVER
	self.winner = w
	self.over_reason = reason
	local t = team or 0
	self.winner_team = t
	if t ~= 0 then
		self:ev({ Ev.GAME_OVER, w, reason, t })
	else
		self:ev({ Ev.GAME_OVER, w, reason })
	end
	self:ev({ Ev.PHASE, Defs.PHASE_OVER, 0 })
	local tn = self.team_names[t]
	if tn ~= nil and (reason == Defs.OVER_DOMINATION or reason == Defs.OVER_TIME) then
		local who = Teams.the(tn)
		self:msg(
			-1,
			Defs.MSG_ALERT,
			if reason == Defs.OVER_DOMINATION
				then who .. (if Teams.plural(tn) then " have won this war" else " has won this war")
				else who .. (if Teams.plural(tn) then " hold the most ground at the last hour: the war is theirs" else " holds the most ground at the last hour: the war is theirs")
		)
	elseif w > 0 and reason == Defs.OVER_DOMINATION then
		self:msg(-1, Defs.MSG_ALERT, "The map answers to " .. self.o_name[w] .. " now")
	elseif w > 0 and reason == Defs.OVER_TIME then
		self:msg(-1, Defs.MSG_ALERT, self.o_name[w] .. " holds the most ground at the last hour: the war is theirs")
	end
end

-- =============================================================================================
-- Stats
-- =============================================================================================

function Sim._gold_int(self: any, id: number): number
	return Defs.trunc(math.min(self.o_gold[id], 2000000000.0))
end

function Sim._stats_rows(self: any): { number }
	local s = {}
	local n = 0
	local o_alive = self.o_alive
	local o_spawned = self.o_spawned
	local o_kind = self.o_kind
	local trunc = Defs.trunc
	for id = 1, self.owner_total do
		-- Alive owners that have spawned, plus humans still choosing a start (their HUD shows
		-- troops and gold during the spawn phase).
		if o_alive[id] == 0 or (o_spawned[id] == 0 and o_kind[id] ~= Defs.KIND_HUMAN) then
			continue
		end
		s[n + 1] = id
		s[n + 2] = self.o_tiles[id]
		s[n + 3] = trunc(self.o_troops[id])
		s[n + 4] = self:_gold_int(id)
		s[n + 5] = trunc(self.o_cap[id])
		s[n + 6] = trunc(self.o_income[id] + self.o_bonus_rate[id])
		n += 6
	end
	return s
end

return Sim
