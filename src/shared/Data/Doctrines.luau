--!strict
-- Doctrines (Warhold's own): at each of the first three eras, every player drafts one of three
-- offered doctrines, a permanent bend of the match. Twenty-four in three tiers; each draft offers three of
-- its tier's eight (which three is a hash of the match seed, the player and the draft, so a match has its own
-- choices and the Sim's random sequence is untouched). Nine more are earned at the War College (Data/Arsenal): one
-- with an `unlock` (a Defs.UNLOCK key) joins the tier's pool only for a player who holds that bit. They widen the choice:
-- the same "modest net value" as the rest (tests/doctrines), so the draft has more paths, not bigger numbers.
--
-- A doctrine is a set of additive levers; a player's multiplier for a lever is 1 + the sum of their picks:
--   gold   all gold income: the base and    cap    troop cap
--          trade, trains and trucks alike (2026-11-06: it was the base alone, 1-3 % of income)
--   lm     landmark bonuses                 conq   gold taken by conquering a nation
--   trade  gold from trade ships and trains
--   atk    attack strength                  def    defence
--   regen  troop regrowth                   claim  cheaper claims on open land
--   rebate share of a building's cost refunded
-- Trade-offs are never paid in cap (a lowered cap would delete troops in one tick). `key` travels in an
-- intent's 16-character `kind` string. `edict` (tier 3) names the active order the doctrine grants.
local IS_ROBLOX = typeof(game) == "Instance"
local Defs: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Core.Defs)
	else require("../Core/Defs")

local Doctrines = {}

export type Doctrine = {
	key: string,
	name: string,
	tier: number,
	glyph: string,
	line: string,
	gold: number?,
	cap: number?,
	lm: number?,
	conq: number?,
	trade: number?,
	atk: number?,
	def: number?,
	regen: number?,
	claim: number?,
	rebate: number?,
	edict: string?,
	--- the Defs.UNLOCK key whose bit lets a player's drafts offer it (nil: every draft may)
	unlock: string?,
	--- a depth match's national ideas and techs (docs/DEPTH_DESIGN.md Phase 3 / 6): the tree ("adm", "mil", "dip",
	--- "tech"), the age it is offered from, and a medieval name for a tech
	cat: string?,
	age: number?,
	m_name: string?,
	unrest: number?,
	food: number?,
	mp: number?,
	prov: number?,
	opinion: number?,
	prestige: number?,
	fort: number?,
	supply: number?,
	general: number?,
	siege: number?,
}

Doctrines.LEVERS = { "gold", "cap", "lm", "conq", "trade", "atk", "def", "regen", "claim", "rebate" }
--- The depth levers (summed, not multiplied: Doctrines.sum): unrest points, food / manpower / prestige / fort / siege
--- shares, provinces allowed before overextension, opinion points with every realm, supply toll share (negative:
--- less), general skill.
Doctrines.DEPTH_LEVERS = { "unrest", "food", "mp", "prov", "opinion", "prestige", "fort", "supply", "general", "siege" }
Doctrines.TIERS = 3
--- A human who has not chosen this many seconds after the draft opened gets the first offer.
Doctrines.DRAFT_TIMEOUT_S = 60
--- Offers per draft.
Doctrines.OFFER_SIZE = 3

Doctrines.LIST = {
	-- tier 1: the Dawn
	{ key = "merchant", name = "Merchant Guild", tier = 1, glyph = "$", line = "Gold flows faster.", gold = 0.20 },
	{ key = "levy", name = "Raised Banners", tier = 1, glyph = "+", line = "A bigger army fits.", cap = 0.15 },
	{ key = "cartographer", name = "Cartographers", tier = 1, glyph = "N", line = "Landmarks pay more.", lm = 0.50 },
	{ key = "tithe", name = "Tithe Collectors", tier = 1, glyph = "%", line = "Conquest pays more.", conq = 0.50, gold = 0.05 },
	{ key = "drill", name = "Drill Sergeants", tier = 1, glyph = "D", line = "Ranks fill back up sooner.", regen = 0.25 },
	{ key = "pioneers", name = "Pioneers", tier = 1, glyph = "P", line = "Open land comes cheap.", claim = 0.40 },
	{ key = "masons", name = "Master Masons", tier = 1, glyph = "M", line = "Every building hands gold back.", rebate = 0.15 },
	{ key = "wardens", name = "Border Wardens", tier = 1, glyph = "W", line = "Your land is harder to take.", def = 0.12 },
	-- tier 2: the Expansion
	{ key = "charter", name = "Trade Charter", tier = 2, glyph = "~", line = "Ships and trucks pay more.", trade = 0.50 },
	{ key = "plunder", name = "Plunderers", tier = 2, glyph = "!", line = "Take a nation's gold twice over.", conq = 1.0, gold = -0.10 },
	{ key = "standing", name = "Standing Army", tier = 2, glyph = "#", line = "A much bigger army, a dearer one.", cap = 0.25, gold = -0.10 },
	{ key = "mercenary", name = "Mercenary Pact", tier = 2, glyph = "&", line = "Hired steel for hard gold.", gold = 0.50, trade = -0.10 },
	{ key = "vanguard", name = "Vanguard", tier = 2, glyph = "V", line = "Strike first, guard less.", atk = 0.18, def = -0.05 },
	{ key = "bastion", name = "Stone Walls", tier = 2, glyph = "B", line = "Walls first, sorties later.", def = 0.22, atk = -0.05 },
	{ key = "conscripts", name = "Conscription", tier = 2, glyph = "C", line = "Every village sends its young.", regen = 0.40, gold = -0.10 },
	{ key = "engineers", name = "Royal Engineers", tier = 2, glyph = "E", line = "Build wide and be paid for it.", rebate = 0.25, trade = 0.10 },
	-- tier 3: the Conflict
	{ key = "coin", name = "Empire of Gold", tier = 3, glyph = "$", line = "Gold in a flood. Edict: Windfall.", gold = 0.40, edict = "windfall" },
	{ key = "grandarmy", name = "Grand Army", tier = 3, glyph = "+", line = "A host of its own. Edict: Rally.", cap = 0.30, edict = "levy" },
	{ key = "wonders", name = "Wonder Keepers", tier = 3, glyph = "N", line = "Landmarks pay twice as much. Edict: Jubilee.", lm = 1.0, edict = "jubilee" },
	{ key = "spoils", name = "Warlord's Plunder", tier = 3, glyph = "!", line = "War pays, and what follows. Edict: Onslaught.", conq = 1.5, trade = 0.10, edict = "blitz" },
	{ key = "ironwall", name = "Iron Wall", tier = 3, glyph = "I", line = "They break on you. Edict: Fortify.", def = 0.30, edict = "fortify" },
	{ key = "lightning", name = "Lightning War", tier = 3, glyph = "L", line = "Over before they form up. Edict: Onslaught.", atk = 0.28, gold = -0.10, edict = "blitz" },
	{ key = "service", name = "National Service", tier = 3, glyph = "S", line = "A nation under arms. Edict: Muster.", regen = 0.50, cap = 0.10, edict = "muster" },
	{ key = "golden", name = "Golden Age", tier = 3, glyph = "G", line = "Everything pays. Edict: Jubilee.", gold = 0.20, trade = 0.20, rebate = 0.10, edict = "jubilee" },
	-- earned at the War College. APPEND ONLY: an offer travels as an index into this list.
	-- the Expansion branch
	{ key = "homestead", name = "Homesteaders", tier = 1, glyph = "H", line = "Settlers first, soldiers after.", claim = 0.50, atk = -0.05, unlock = "d_homestead" },
	{ key = "surveyors", name = "Royal Surveyors", tier = 2, glyph = "R", line = "Chart the land and claim it cheap.", lm = 0.50, claim = 0.25, trade = -0.20, unlock = "d_surveyors" },
	{ key = "frontier", name = "Frontier Marches", tier = 3, glyph = "F", line = "Every field a fort. Edict: Muster.", claim = 0.60, regen = 0.30, gold = -0.10, edict = "muster", unlock = "d_frontier" },
	-- the Economy branch
	{ key = "customs", name = "Customs House", tier = 1, glyph = "U", line = "Every ship pays at your door.", trade = 0.40, gold = 0.05, conq = -0.20, unlock = "d_customs" },
	{ key = "bankers", name = "Royal Bank", tier = 2, glyph = "K", line = "Gold makes gold. Soldiers wait.", gold = 0.20, rebate = 0.10, atk = -0.05, unlock = "d_bankers" },
	{ key = "treasury", name = "Grand Treasury", tier = 3, glyph = "T", line = "A vault for every wonder. Edict: Windfall.", gold = 0.25, lm = 0.50, def = -0.05, edict = "windfall", unlock = "d_treasury" },
	-- the War branch
	{ key = "skirmish", name = "Skirmishers", tier = 1, glyph = "A", line = "Quick feet, quick returns.", atk = 0.12, regen = 0.10, def = -0.05, unlock = "d_skirmish" },
	{ key = "siege", name = "Siege School", tier = 2, glyph = "Y", line = "Break the walls, keep the stone.", atk = 0.12, rebate = 0.15, gold = -0.05, unlock = "d_siege" },
	{ key = "praetorian", name = "Praetorian Guard", tier = 3, glyph = "Q", line = "The best, at a price. Edict: Fortify.", def = 0.20, atk = 0.15, gold = -0.15, edict = "fortify", unlock = "d_praetorian" },
	-- National ideas (a depth match: three picks an age, one from each tree; tier 0 keeps them out of the plain
	-- drafts). Ages 1-2 offer the early four of a tree, ages 3-4 the late four; one taken is never offered again.
	-- Administrative
	{ key = "i_census", name = "Royal Census", tier = 0, cat = "adm", age = 1, glyph = "C", line = "Count every hearth, tax every one.", gold = 0.12, unrest = 3 },
	{ key = "i_courts", name = "Royal Courts", tier = 0, cat = "adm", age = 1, glyph = "J", line = "Justice keeps the peace.", unrest = -8 },
	{ key = "i_granaries", name = "Public Granaries", tier = 0, cat = "adm", age = 1, glyph = "G", line = "Stores for the lean years.", food = 0.30, regen = 0.05 },
	{ key = "i_bureaucracy", name = "Bureaucracy", tier = 0, cat = "adm", age = 1, glyph = "B", line = "Clerks hold a wider realm together.", prov = 8 },
	{ key = "i_mint", name = "Royal Mint", tier = 0, cat = "adm", age = 3, glyph = "M", line = "Good gold, and plenty of it.", gold = 0.20, trade = 0.10 },
	{ key = "i_roads", name = "Royal Roads", tier = 0, cat = "adm", age = 3, glyph = "R", line = "Supplies reach the far marches.", supply = -0.5, regen = 0.05 },
	{ key = "i_charters", name = "Town Charters", tier = 0, cat = "adm", age = 3, glyph = "T", line = "Free towns, loyal towns.", unrest = -10, gold = 0.05 },
	{ key = "i_centralism", name = "Centralism", tier = 0, cat = "adm", age = 3, glyph = "Z", line = "One crown over every province.", prov = 15, unrest = 2 },
	-- Military
	{ key = "i_levies", name = "Feudal Levies", tier = 0, cat = "mil", age = 1, glyph = "L", line = "Every lord brings his men.", mp = 0.30, cap = 0.05 },
	{ key = "i_drill", name = "Drill and Discipline", tier = 0, cat = "mil", age = 1, glyph = "D", line = "They hold the line.", def = 0.10, general = 1 },
	{ key = "i_raiders", name = "Raiders", tier = 0, cat = "mil", age = 1, glyph = "A", line = "Strike fast, strike deep.", atk = 0.10, supply = -0.25 },
	{ key = "i_castles", name = "Castle Building", tier = 0, cat = "mil", age = 1, glyph = "F", line = "Walls that outlast sieges.", fort = 0.40, def = 0.05 },
	{ key = "i_standing", name = "Professional Army", tier = 0, cat = "mil", age = 3, glyph = "P", line = "Paid soldiers, sharp officers.", atk = 0.10, general = 1, gold = -0.05 },
	{ key = "i_engines", name = "Siege Engineers", tier = 0, cat = "mil", age = 3, glyph = "E", line = "No wall stands long.", siege = 0.40, atk = 0.05 },
	{ key = "i_reserves", name = "Reserves", tier = 0, cat = "mil", age = 3, glyph = "V", line = "Fresh men behind every line.", mp = 0.40, regen = 0.10 },
	{ key = "i_logistics", name = "Logistics", tier = 0, cat = "mil", age = 3, glyph = "O", line = "Armies fed far from home.", supply = -0.5, food = 0.15 },
	-- Diplomatic
	{ key = "i_envoys", name = "Envoys", tier = 0, cat = "dip", age = 1, glyph = "N", line = "Friends come easier.", opinion = 15 },
	{ key = "i_marriages", name = "Royal Marriages", tier = 0, cat = "dip", age = 1, glyph = "W", line = "Every court is family.", opinion = 10, unrest = -3 },
	{ key = "i_claims", name = "Fabricated Claims", tier = 0, cat = "dip", age = 1, glyph = "X", line = "Every war has its reason.", opinion = -5, conq = 0.30 },
	{ key = "i_tribute", name = "Tributaries", tier = 0, cat = "dip", age = 1, glyph = "U", line = "Vassals pay more.", trade = 0.20, prestige = 0.10 },
	{ key = "i_prestige", name = "Glory of the Crown", tier = 0, cat = "dip", age = 3, glyph = "K", line = "Every victory sung.", prestige = 0.40 },
	{ key = "i_spies", name = "Spymasters", tier = 0, cat = "dip", age = 3, glyph = "S", line = "Know them before you fight them.", atk = 0.05, def = 0.05, opinion = 5 },
	{ key = "i_trade", name = "Trade Leagues", tier = 0, cat = "dip", age = 3, glyph = "~", line = "Ships of every flag in your ports.", trade = 0.30, opinion = 5 },
	{ key = "i_balance", name = "Balance of Power", tier = 0, cat = "dip", age = 3, glyph = "=", line = "Peace on your terms.", opinion = 20, unrest = -3 },
	-- Techs: halfway through each age, one of three of that age (a medieval match reads `m_name`)
	{ key = "t_plough", name = "Mechanised Farming", m_name = "Heavy Plough", tier = 0, cat = "tech", age = 1, glyph = "1", line = "More food from every field.", food = 0.30 },
	{ key = "t_stirrup", name = "Motor Transport", m_name = "Stirrups", tier = 0, cat = "tech", age = 1, glyph = "1", line = "Faster, harder attacks.", atk = 0.08 },
	{ key = "t_masonry", name = "Reinforced Concrete", m_name = "Masonry", tier = 0, cat = "tech", age = 1, glyph = "1", line = "Stronger forts.", fort = 0.30, def = 0.04 },
	{ key = "t_banking", name = "Central Banking", m_name = "Banking", tier = 0, cat = "tech", age = 2, glyph = "2", line = "Gold works for you.", gold = 0.15 },
	{ key = "t_crossbow", name = "Automatic Rifles", m_name = "Crossbows", tier = 0, cat = "tech", age = 2, glyph = "2", line = "Every soldier a marksman.", atk = 0.06, def = 0.06 },
	{ key = "t_mills", name = "Electrification", m_name = "Water Mills", tier = 0, cat = "tech", age = 2, glyph = "2", line = "Industry grows the realm.", gold = 0.05, mp = 0.20 },
	{ key = "t_compass", name = "Radar", m_name = "Compass", tier = 0, cat = "tech", age = 3, glyph = "3", line = "Ships and supplies go further.", trade = 0.20, supply = -0.30 },
	{ key = "t_trebuchet", name = "Artillery Doctrine", m_name = "Counterweight Trebuchet", tier = 0, cat = "tech", age = 3, glyph = "3", line = "Walls fall faster.", siege = 0.50 },
	{ key = "t_medicine", name = "Antibiotics", m_name = "Hospitals", tier = 0, cat = "tech", age = 3, glyph = "3", line = "The wounded come back.", regen = 0.15, unrest = -3 },
	{ key = "t_gunpowder", name = "Mechanised Warfare", m_name = "Gunpowder", tier = 0, cat = "tech", age = 4, glyph = "4", line = "A new kind of war.", atk = 0.12, siege = 0.20 },
	{ key = "t_printing", name = "Mass Media", m_name = "Printing Press", tier = 0, cat = "tech", age = 4, glyph = "4", line = "One story for the whole realm.", unrest = -8, prestige = 0.20 },
	{ key = "t_admin", name = "Computing", m_name = "Double-Entry Books", tier = 0, cat = "tech", age = 4, glyph = "4", line = "Rule more with less.", prov = 12, gold = 0.05 },
} :: { Doctrine }

--- The active orders tier 3 doctrines grant (Core/SimDoctrines). One cooldown covers them all. `gold_s`: that
--- many seconds of income at once; `troops`: that share of the cap as troops, up to the cap; `lever` / `mult`
--- for `secs`: a timed multiplier.
Doctrines.EDICT_ORDER = { "windfall", "levy", "jubilee", "blitz", "fortify", "muster" }
Doctrines.EDICTS = {
	windfall = { name = "Windfall", line = "A minute of income at once", gold_s = 60 },
	levy = { name = "Rally", line = "A fifth of your cap as troops", troops = 0.2 },
	jubilee = { name = "Jubilee", line = "Double gold for a minute", lever = "gold", mult = 2.0, secs = 60 },
	blitz = { name = "Onslaught", line = "+40% attack for 45 seconds", lever = "atk", mult = 1.4, secs = 45 },
	fortify = { name = "Fortify", line = "+50% defence for a minute", lever = "def", mult = 1.5, secs = 60 },
	muster = { name = "Muster", line = "Triple regrowth for a minute", lever = "regen", mult = 3.0, secs = 60 },
} :: { [string]: any }

--- key -> doctrine, and key -> its index in LIST (what travels in events: a small integer).
Doctrines.BY_KEY = {} :: { [string]: Doctrine }
Doctrines.INDEX = {} :: { [string]: number }
for i, d in Doctrines.LIST do
	Doctrines.BY_KEY[d.key] = d
	Doctrines.INDEX[d.key] = i
end

--- The doctrines of a tier a player with Defs.UNLOCK mask `mask` may be offered (nil or 0: the ones everyone has), in
--- LIST order.
function Doctrines.pool(tier: number, mask: number?): { Doctrine }
	local m = mask or 0
	local out = {}
	for _, d in Doctrines.LIST do
		if d.tier == tier and (d.unlock == nil or bit32.band(m, Defs.UNLOCK[d.unlock]) ~= 0) then
			table.insert(out, d)
		end
	end
	return out
end

--- A well-mixed integer from three small ones, in 0 .. 1000002. Stepwise modulo keeps every product
--- exact in a double (a plain product of a 31-bit seed would not be).
function Doctrines.mix(seed: number, id: number, draft: number): number
	local a = (math.floor(seed) % 100003) * 7919
	local b = (math.floor(id) % 4099) * 104729
	local c = (math.floor(draft) % 97) * 1299709
	local h = (a + b + c) % 1000003
	h = (h * 48271 + 12345) % 1000003
	return (h * 69621 + 1) % 1000003
end

--- The three offered for `draft` (1-based) to owner `id` in a match with `seed`, who holds Defs.UNLOCK mask `mask`:
--- three distinct doctrines of the draft's pool chosen by hash; indices into LIST, in LIST order. Pure: the same
--- arguments give the same three, and a mask with no doctrine bits gives what everyone gets.
function Doctrines.offer(seed: number, id: number, draft: number, mask: number?): { number }
	local tier = math.clamp(draft, 1, Doctrines.TIERS)
	local pool = Doctrines.pool(tier, mask)
	local h = Doctrines.mix(seed, id, draft)
	local taken = {}
	for _ = 1, Doctrines.OFFER_SIZE do
		h = (h * 48271 + 11) % 1000003
		local k = h % #pool + 1
		while taken[k] do
			k = k % #pool + 1
		end
		taken[k] = true
	end
	local out = {}
	for i, d in pool do
		if taken[i] then
			table.insert(out, Doctrines.INDEX[d.key])
		end
	end
	return out
end

--- The idea trees of a depth match, in the order an age offers them, and their names.
Doctrines.IDEA_CATS = { "adm", "mil", "dip" }
Doctrines.CAT_NAMES = { adm = "Administrative", mil = "Military", dip = "Diplomatic", tech = "Technology" }
--- Drafts an age holds in a depth match: three ideas and a tech. Draft d is age (d - 1) // 4 + 1, slot (d - 1) % 4 + 1.
Doctrines.DEPTH_PER_AGE = 4

--- What depth draft `draft` is: its age and tree ("adm" / "mil" / "dip" / "tech").
function Doctrines.depth_draft(draft: number): (number, string)
	local age = (draft - 1) // Doctrines.DEPTH_PER_AGE + 1
	local slot = (draft - 1) % Doctrines.DEPTH_PER_AGE + 1
	return age, if slot <= 3 then Doctrines.IDEA_CATS[slot] else "tech"
end

--- A depth draft's offer: up to three of its tree's cards for its age (ideas: the early four in ages 1-2, the late four
--- after; techs: that age's three), none `taken` already; by hash, as Doctrines.offer. Indices into LIST.
function Doctrines.offer_depth(seed: number, id: number, draft: number, taken: { [string]: boolean }?): { number }
	local age, cat = Doctrines.depth_draft(draft)
	local want = if cat == "tech" then math.clamp(age, 1, 4) elseif age <= 2 then 1 else 3
	local pool = {}
	for _, d in Doctrines.LIST do
		if d.cat == cat and d.age == want and not (taken ~= nil and taken[d.key]) then
			table.insert(pool, d)
		end
	end
	local h = Doctrines.mix(seed, id, draft + 50)
	local out = {}
	while #out < math.min(Doctrines.OFFER_SIZE, #pool) do
		h = (h * 48271 + 11) % 1000003
		local k = h % #pool + 1
		local idx = Doctrines.INDEX[pool[k].key]
		if not table.find(out, idx) then
			table.insert(out, idx)
		end
	end
	table.sort(out)
	return out
end

--- The sum of depth lever `lever` over `keys` (0 when none has it).
function Doctrines.sum(keys: { string }, lever: string): number
	local m = 0.0
	for _, k in keys do
		local d = Doctrines.BY_KEY[k]
		if d ~= nil then
			m += (d :: any)[lever] or 0
		end
	end
	return m
end

--- The multiplier on `lever` of a player who picked `keys`.
function Doctrines.mult(keys: { string }, lever: string): number
	local m = 1.0
	for _, k in keys do
		local d = Doctrines.BY_KEY[k]
		if d ~= nil then
			m += (d :: any)[lever] or 0
		end
	end
	return math.max(m, 0.2)
end

--- One line of numbers for a doctrine, "+50% income, -10% trade gold": what a card prints under its name ("income":
--- the gold lever, on all of it).
function Doctrines.effects(d: Doctrine): { string }
	local names = {
		gold = "income",
		cap = "troop cap",
		lm = "landmark bonuses",
		conq = "conquest gold",
		trade = "trade gold",
		atk = "attack",
		def = "defence",
		regen = "troop regrowth",
		claim = "cheaper claims",
		rebate = "building refund",
		unrest = "unrest",
		food = "food",
		mp = "manpower",
		prov = "province limit",
		opinion = "opinion abroad",
		prestige = "prestige",
		fort = "fort strength",
		supply = "supply losses",
		general = "general skill",
		siege = "siege speed",
	}
	local out = {}
	for _, lever in Doctrines.LEVERS do
		local v = (d :: any)[lever]
		if v ~= nil and v ~= 0 then
			table.insert(out, string.format("%s%d%% %s", if v > 0 then "+" else "-", math.floor(math.abs(v) * 100 + 0.5), names[lever]))
		end
	end
	-- (the depth levers: points for unrest, opinion, provinces and general skill, shares for the rest)
	for _, lever in Doctrines.DEPTH_LEVERS do
		local v = (d :: any)[lever]
		if v ~= nil and v ~= 0 then
			local points = lever == "unrest" or lever == "opinion" or lever == "prov" or lever == "general"
			local n = if points then math.floor(math.abs(v) + 0.5) else math.floor(math.abs(v) * 100 + 0.5)
			table.insert(out, string.format("%s%d%s %s", if v > 0 then "+" else "-", n, if points then "" else "%", names[lever]))
		end
	end
	return out
end

return Doctrines
