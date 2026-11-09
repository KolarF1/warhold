--!strict
-- Game modes (Conquer the World's own): ways to play a match, chosen on the solo menu; public matches rotate
-- through the ones that suit a crowd. A mode is a set of match-config keys (Core/Sim, Core/SimModes) and nothing
-- else, so a mission (Data/Missions) can use one too.
local Modes = {}

export type Mode = { key: string, name: string, short: string?, line: string, config: { [string]: any }, public: number? }

Modes.DEFAULT = "classic"

Modes.LIST = {
	{
		key = "classic",
		name = "Conquest",
		line = "The full war. Hold most of the world to win.",
		config = {},
		public = 4,
	},
	{
		key = "blitz",
		name = "Blitz",
		line = "The ages fly by, gold and troops flood in. Hold 60% to win.",
		config = {
			era_ticks = { 0, 600, 1800, 3600 },
			win_share = 0.6,
			draft_timeout_s = 30,
			boost = { gold = 1.5, regen = 1.5 },
		},
		public = 1,
	},
	{
		key = "crown",
		name = "King of the Hill",
		short = "The Hill",
		line = "Hold the Crown at the heart to win. Conquest alone needs 95%.",
		-- crown_ticks: the hold on World; the Sim shrinks it, and when the Crown opens, with the ages on a smaller map
		-- (Sim.age_scale). win_share (owner's call, 2026-11-06): conquest needs almost everything, so the Crown decides.
		config = { crown_ticks = 6000, win_share = 0.95 },
		public = 1,
	},
	{
		key = "deadline",
		name = "Deadline",
		line = "Twenty minutes on the clock. Most land when it ends wins.",
		-- (win_share: the clock decides, not an early conquest; release audit 2026-11-07 saw a Deadline won by domination
		-- at 7 minutes on South America)
		-- (win_share 1.0: only taking everything ends it before the bell; at 95% bots still finished small maps in 10-15
		-- minutes: release audit 2026-11-07)
		config = { solo_clock = true, time_limit_s = 1200, win_share = 1.0, clock_is_war = true },
	},
	{
		key = "skirmish",
		name = "Skirmish",
		line = "Twelve nations and open land. Room to grow.",
		config = { nation_limit = 12, tribes_scale = 0.4 },
	},
	{
		key = "totalwar",
		name = "Total War",
		line = "No pacts. Everyone stands alone.",
		config = { no_alliances = true },
		public = 1,
	},
	{
		-- (the owner, 2026-11-08: stronger AI and harder, more grounded play, alone or online, but never in the public
		-- rotation: online it is its own queue, LobbyRules.MODE_HARDCORE. Core/Sim reads `hardcore`: Brutal nations, every
		-- bot player sharp and as harsh on people as the nations, no world events; troops regrow a fifth slower.)
		key = "hardcore",
		name = "Hardcore",
		line = "Brutal rivals, no world events, slower regrowth. A long, hard war.",
		config = { hardcore = true, boost = { regen = 0.8 } },
	},
} :: { Mode }

Modes.BY_KEY = {} :: { [string]: Mode }
for _, m in Modes.LIST do
	Modes.BY_KEY[m.key] = m
end

--- `config` with mode `key`'s keys filled in (a key the caller already set stays); stamps `config.mode`.
function Modes.apply(config: { [string]: any }, key: string?): { [string]: any }
	local m = Modes.BY_KEY[key or Modes.DEFAULT] or Modes.BY_KEY[Modes.DEFAULT]
	config.mode = m.key
	for k, v in m.config do
		if k == "tribes_scale" then
			-- (no count yet: the Sim scales the map's own default)
			if type(config.tribes) == "number" then
				config.tribes = math.floor(config.tribes * v)
			else
				config.tribes_scale = v
			end
		elseif k == "time_limit_s" then
			-- (a multiplayer match keeps its own when it is shorter; a mode whose clock IS the war, Deadline, always runs on
			-- its own: release audit 2026-11-07, a public Deadline ran the 35-minute public clock)
			if (config.time_limit_s or 0) == 0 or (m.config.clock_is_war == true and v < config.time_limit_s) then
				config.time_limit_s = v
			end
		elseif config[k] == nil then
			config[k] = v
		end
	end
	return config
end

--- Maps of scattered islands (the largest landmass holds under this share of the land: Data/Eras.MAINLAND) can't be
--- conquered to the win share inside a public war's clock, every gain a sea landing (release audit 2026-11-07: Thousand
--- Isles ran out the clock at 44% of 80%). There a public war is one of ISLAND_MODES, whose own goal fits.
Modes.ISLAND_MAINLAND = 0.3
Modes.ISLAND_MODES = { "deadline", "crown" }

local Eras: any = if typeof(game) == "Instance" then require((script :: any).Parent.Eras) else (require :: any)("./Eras")

--- True when `map_id` (a base id or "id@80") is scattered islands.
function Modes.islands(map_id: string?): boolean
	if type(map_id) ~= "string" then
		return false
	end
	local f = Eras.MAINLAND[string.match(map_id, "^(.-)@%d+$") or map_id]
	return type(f) == "number" and f < Modes.ISLAND_MAINLAND
end

--- The mode of the public match in lobby `id` on `map_id`: pure, so a hub's card can name it long before the match server
--- opens, and the match plays what the card said.
function Modes.lobby_pick(id: string, map_id: string?): string
	local h = 5381
	for i = 1, #id do
		h = (h * 33 + string.byte(id, i)) % 2147483647
	end
	local key = Modes.public_pick(h)
	if Modes.islands(map_id) and table.find(Modes.ISLAND_MODES, key) == nil then
		key = Modes.ISLAND_MODES[h % #Modes.ISLAND_MODES + 1]
	end
	return key
end

--- A public match's start date (Data/Periods; the owner, 2026-11-08: the dates join the rotation with the maps): on a
--- map that offers dates, PERIOD_SHARE of lobbies play one of them (evenly), the rest today's world. Pure in the lobby's
--- id, like lobby_pick: the card and the match agree. nil: today's world.
Modes.PERIOD_SHARE = 0.5

function Modes.period_pick(id: string, map_id: string?): string?
	local Periods: any = if typeof(game) == "Instance" then require((script :: any).Parent.Periods) else (require :: any)("./Periods")
	local offered = Periods.offered(if type(map_id) == "string" then (string.match(map_id, "^(.-)@%d+$") or map_id) else nil)
	if #offered == 0 then
		return nil
	end
	local h = 7919
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 2147483647
	end
	if (h % 1000) / 1000 >= Modes.PERIOD_SHARE then
		return nil
	end
	return offered[(h // 1000) % #offered + 1]
end

--- The mode of a public match with `seed`: weighted by `public`. Pure.
function Modes.public_pick(seed: number): string
	local total = 0
	for _, m in Modes.LIST do
		total += m.public or 0
	end
	local x = (math.floor(seed) * 48271 + 12345) % 1000003 % total
	for _, m in Modes.LIST do
		x -= m.public or 0
		if x < 0 then
			return m.key
		end
	end
	return Modes.DEFAULT
end

return Modes
