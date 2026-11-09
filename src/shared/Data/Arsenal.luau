--!strict
-- The War College (saved as `unlocks`, keys and bits kept so saves load): what a ruler earns for good with Renown
-- (Data/Stars). A tree of three branches, Expansion, Economy and War: weapons and orders the Sim checks by bit, and
-- doctrines that join the player's draft offers (Data/Doctrines `unlock`, Doctrines.offer).
--
--   stars    the price in Renown, the currency earned by playing
--   product  the developer product that unlocks it for Robux (Data/Products; its `robux` is the
--            price shown until Roblox answers with the real one); nil: Renown only
--   bonus    Renown paid once with the unlock, however it was bought (none has one now; the field stays for a future item)
--   bit      the Defs.UNLOCK bit the Sim checks
--   branch, row, lane   where it stands in the tree (Arsenal.BRANCHES; row 1 at the top, lane 1 or 2)
--   needs    the items that must be yours before Renown can buy it (server/Purchases.buy_unlock). An item already
--            owned stays owned whatever it needs, and a Robux receipt always grants.
--
-- An unlock is saved on the player's record (server/Purchases: `unlocks`), by ProcessReceipt for a
-- Robux purchase or by Purchases.buy_unlock for Renown. The rules and numbers of each unit are the
-- Sim's (Core/Rules "The Arsenal", Core/SimArsenal); the copy here only describes them.
local IS_ROBLOX = typeof(game) == "Instance"
local Defs: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Core.Defs)
	else require("../Core/Defs")

local Arsenal = {}

export type Item = {
	key: string,
	title: string,
	--- "structure" (built on your land), "nuke" (launched from a silo), "strike" (fired from its
	--- structure), "call" (an instant order), "boost" (always on), "doctrine" (joins your draft offers)
	kind: string,
	icon: string,
	tagline: string,
	blurb: string,
	perks: { string },
	--- the shop's one sentence: what it does, in plain words (2026-10-24: the Arsenal UI was too
	--- confusing and had to be simpler)
	plain: string,
	--- the shop's two short facts
	facts: { string },
	stars: number?,
	product: string?,
	bonus: number?,
	bit: number,
	--- the build / launch kinds it opens in a match (UIRules kinds)
	opens: { string },
	--- card colours (top, bottom), 0xRRGGBB
	color: { number },
	branch: string,
	row: number,
	lane: number,
	needs: { string },
	--- the Data/Doctrines key it adds to the draft ("doctrine" items)
	doctrine: string?,
}

--- The tree's branches, in order: what each is for, and its mark.
Arsenal.BRANCHES = {
	{ key = "expansion", name = "Expansion", icon = "land", line = "More ground, sooner." },
	{ key = "economy", name = "Economy", icon = "gold", line = "Gold that outlasts the war." },
	{ key = "war", name = "War", icon = "iron", line = "Weapons and the will to use them." },
}

--- By branch, top of the tree first.
Arsenal.ITEMS = {
	-- Expansion
	{
		key = "reinforce",
		title = "Harvest Levy",
		kind = "call",
		icon = "reinforce",
		tagline = "Empty the fields for an army",
		blurb = "Send for the harvest hands: 30% of your troop cap joins at once for 60K gold. Then your land regrows no troops for 20 seconds. Ready again after 50.",
		perks = { "+30% OF YOUR CAP", "NO REGROWTH FOR 20 S" },
		plain = "The harvest hands take up arms: 30% of your troop cap now, then no regrowth for 20 seconds.",
		facts = { "+30% of cap", "No regrowth 20 s" },
		stars = 12500,
		product = "unlock_reinforce",
		bit = Defs.UNLOCK.reinforce,
		opens = { "reinforce" },
		color = { 0x35B86B, 0x0E5A34 },
		branch = "expansion",
		row = 1,
		lane = 1,
		needs = {},
	},
	{
		key = "airfield",
		title = "Sky Raid",
		kind = "structure",
		icon = "airfield",
		tagline = "Aerodromes that ground Flak and Launch Sites",
		blurb = "Build Aerodromes and send Sky Raids up to 118 tiles. Every Flak Battery and Launch Site under the bombs is emptied and can't fire for 25 seconds. Few troops die and no building falls. Rearms in 45 seconds.",
		perks = { "UNLOCKS AERODROMES", "GROUNDS FLAK 25 S" },
		plain = "Raid an enemy's Flak and Launch Sites: they can't fire for 25 seconds, so your warheads get through.",
		facts = { "Reach: 118 tiles", "Grounds for 25 s" },
		stars = 85000,
		product = "unlock_airfield",
		bit = Defs.UNLOCK.airfield,
		opens = { "airfield", "airstrike" },
		color = { 0x2FB7C9, 0x0D5670 },
		branch = "expansion",
		row = 2,
		lane = 1,
		needs = { "reinforce" },
	},
	{
		key = "d_homestead",
		title = "Homesteaders",
		kind = "doctrine",
		icon = "d_homestead",
		tagline = "A first-draft doctrine: cheap open land",
		blurb = "Homesteaders can now come up in your first draft: claims cost 50% less, attack falls 5%.",
		perks = { "FIRST DRAFT", "50% CHEAPER CLAIMS" },
		plain = "Your first draft may now offer Homesteaders: claims cost 50% less, attack falls 5%.",
		facts = { "First draft", "Cheaper claims" },
		stars = 5000,
		bit = Defs.UNLOCK.d_homestead,
		opens = {},
		color = { 0x8FBF4A, 0x3C5A16 },
		branch = "expansion",
		row = 1,
		lane = 2,
		needs = {},
		doctrine = "homestead",
	},
	{
		key = "d_surveyors",
		title = "Royal Surveyors",
		kind = "doctrine",
		icon = "d_surveyors",
		tagline = "A second-draft doctrine: landmarks and land",
		blurb = "Royal Surveyors can now come up in your second draft: landmarks pay 50% more, claims cost 25% less, trade falls 20%.",
		perks = { "SECOND DRAFT", "+50% LANDMARKS" },
		plain = "Your second draft may now offer Royal Surveyors: landmarks +50%, claims 25% cheaper, trade -20%.",
		facts = { "Second draft", "Landmarks pay more" },
		stars = 12500,
		bit = Defs.UNLOCK.d_surveyors,
		opens = {},
		color = { 0x8FBF4A, 0x3C5A16 },
		branch = "expansion",
		row = 2,
		lane = 2,
		needs = { "d_homestead" },
		doctrine = "surveyors",
	},
	{
		key = "d_frontier",
		title = "Frontier Marches",
		kind = "doctrine",
		icon = "d_frontier",
		tagline = "A third-draft doctrine with an edict: Muster",
		blurb = "Frontier Marches can now come up in your third draft: claims cost 60% less, regrowth +30%, gold -10%, and the Muster edict.",
		perks = { "THIRD DRAFT", "EDICT: MUSTER" },
		plain = "Your third draft may now offer Frontier Marches: claims 60% cheaper, regrowth +30%, gold -10%. Edict: Muster.",
		facts = { "Third draft", "Edict: Muster" },
		stars = 25000,
		bit = Defs.UNLOCK.d_frontier,
		opens = {},
		color = { 0x8FBF4A, 0x3C5A16 },
		branch = "expansion",
		row = 3,
		lane = 2,
		needs = { "d_surveyors", "reinforce" },
		doctrine = "frontier",
	},
	-- Economy
	{
		key = "stars2x",
		title = "War Chest",
		kind = "boost",
		icon = "war_chest",
		tagline = "Every new age fills your treasury",
		blurb = "Each time a new age opens, a full minute of your income lands in your treasury at once, in every war, for good.",
		perks = { "EVERY NEW AGE", "A MINUTE OF INCOME" },
		plain = "Each new age pays a full minute of your income at once.",
		facts = { "Every new age", "A minute of income" },
		stars = 15000,
		product = "unlock_stars2x",
		bit = Defs.UNLOCK.stars2x,
		opens = {},
		color = { 0xFFC83D, 0x9A6200 },
		branch = "economy",
		row = 1,
		lane = 1,
		needs = {},
	},
	{
		key = "reload2x",
		title = "Salvage Crews",
		kind = "boost",
		icon = "salvage",
		tagline = "What you lose still pays",
		blurb = "When an enemy wrecks, burns or takes a building of yours, your crews bring back 40% of its price in gold. A building you pull down yourself pays nothing.",
		perks = { "40% BACK IN GOLD", "WRECKED OR TAKEN" },
		plain = "When an enemy wrecks or takes a building of yours, 40% of its price comes back as gold.",
		facts = { "40% back", "Wrecked or taken" },
		stars = 45000,
		product = "unlock_reload2x",
		bit = Defs.UNLOCK.reload2x,
		opens = {},
		color = { 0xE85BB0, 0x7A1A5A },
		branch = "economy",
		row = 2,
		lane = 1,
		needs = { "stars2x" },
	},
	{
		key = "d_customs",
		title = "Customs House",
		kind = "doctrine",
		icon = "d_customs",
		tagline = "A first-draft doctrine: trade at your door",
		blurb = "Customs House can now come up in your first draft: trade +40%, gold +5%, conquest gold -20%.",
		perks = { "FIRST DRAFT", "+40% TRADE" },
		plain = "Your first draft may now offer Customs House: trade +40%, gold +5%, conquest gold -20%.",
		facts = { "First draft", "Trade pays more" },
		stars = 5000,
		bit = Defs.UNLOCK.d_customs,
		opens = {},
		color = { 0xE0B040, 0x6A4A0C },
		branch = "economy",
		row = 1,
		lane = 2,
		needs = {},
		doctrine = "customs",
	},
	{
		key = "d_bankers",
		title = "Royal Bank",
		kind = "doctrine",
		icon = "d_bankers",
		tagline = "A second-draft doctrine: gold makes gold",
		blurb = "Royal Bank can now come up in your second draft: gold +20%, building refund +10%, attack -5%.",
		perks = { "SECOND DRAFT", "+20% GOLD" },
		plain = "Your second draft may now offer Royal Bank: gold +20%, building refund +10%, attack -5%.",
		facts = { "Second draft", "Gold and refunds" },
		stars = 12500,
		bit = Defs.UNLOCK.d_bankers,
		opens = {},
		color = { 0xE0B040, 0x6A4A0C },
		branch = "economy",
		row = 2,
		lane = 2,
		needs = { "d_customs" },
		doctrine = "bankers",
	},
	{
		key = "d_treasury",
		title = "Grand Treasury",
		kind = "doctrine",
		icon = "d_treasury",
		tagline = "A third-draft doctrine with an edict: Windfall",
		blurb = "Grand Treasury can now come up in your third draft: gold +25%, landmarks +50%, defence -5%, and the Windfall edict.",
		perks = { "THIRD DRAFT", "EDICT: WINDFALL" },
		plain = "Your third draft may now offer Grand Treasury: gold +25%, landmarks +50%, defence -5%. Edict: Windfall.",
		facts = { "Third draft", "Edict: Windfall" },
		stars = 25000,
		bit = Defs.UNLOCK.d_treasury,
		opens = {},
		color = { 0xE0B040, 0x6A4A0C },
		branch = "economy",
		row = 3,
		lane = 2,
		needs = { "d_bankers" },
		doctrine = "treasury",
	},
	-- War
	{
		key = "artillery",
		title = "Long Guns",
		kind = "structure",
		icon = "artillery",
		tagline = "Only fires on those at war with you",
		blurb = "A battery that stays quiet until war reaches it. It shells any nation marching on you, or that you march on, within 62 tiles, and each shell costs 7% of a force marching on you. It never touches a building.",
		perks = { "BREAKS MARCHES", "SILENT IN PEACE" },
		plain = "Guns on your land that wait for war, then cut down any force marching on you within 62 tiles.",
		facts = { "Breaks marches", "Reach: 62 tiles" },
		stars = 15000,
		product = "unlock_artillery",
		bit = Defs.UNLOCK.artillery,
		opens = { "artillery" },
		color = { 0x4C8DF0, 0x1A3A8A },
		branch = "war",
		row = 1,
		lane = 1,
		needs = {},
	},
	{
		key = "mega",
		title = "Sunbreaker",
		kind = "nuke",
		icon = "mega",
		tagline = "Burns all that stands, takes no land",
		blurb = "Burns every building and ship within 50 tiles, and up to a quarter of each army caught under it. The land stays whole and unpoisoned: march in and it's yours. Fires from your Launch Sites.",
		perks = { "TAKES NO LAND", "EACH SHOT 2.2M GOLD" },
		plain = "Burns every building within 50 tiles and thins the armies there, but leaves the land clean for you to march on.",
		facts = { "Burns 50 tiles", "Leaves the land clean" },
		stars = 17500,
		product = "unlock_mega",
		bit = Defs.UNLOCK.mega,
		opens = { "mega" },
		color = { 0xE2483A, 0x7A1420 },
		branch = "war",
		row = 2,
		lane = 1,
		needs = { "artillery" },
	},
	{
		key = "scatter",
		title = "Shatter Line",
		kind = "nuke",
		icon = "scatter",
		tagline = "A wall of fire across a nation",
		blurb = "A small burst at your aim, and 6 shards in a straight line across it, 17 tiles apart: a strip of poisoned land about 100 tiles long. Fires from your Launch Sites.",
		perks = { "6 SHARDS IN A LINE", "SPLITS A NATION" },
		plain = "Six shards fall in one straight line across your aim and leave a strip of poisoned land.",
		facts = { "Six in a line", "100 tiles long" },
		stars = 27500,
		product = "unlock_scatter",
		bit = Defs.UNLOCK.scatter,
		opens = { "scatter" },
		color = { 0xF08A24, 0x8A3A0C },
		branch = "war",
		row = 3,
		lane = 1,
		needs = { "mega" },
	},
	{
		key = "railgun",
		title = "Lance Cannon",
		kind = "structure",
		icon = "railgun",
		tagline = "One shot through a line of buildings",
		blurb = "Reaches 340 tiles. Each shot runs through every enemy building along the last 70 tiles of its line and takes a level off each. It kills no troops, and no Flak can catch it. Reloads in 40 seconds.",
		perks = { "340-TILE REACH", "PIERCES A LINE" },
		plain = "Aim down a line of enemy buildings: the shot goes through them all and takes a level off each.",
		facts = { "Reach: 340 tiles", "Hits a whole line" },
		stars = 160000,
		product = "unlock_railgun",
		bit = Defs.UNLOCK.railgun,
		opens = { "railgun", "slug" },
		color = { 0xA35BFF, 0x3D1A8A },
		branch = "war",
		row = 4,
		lane = 1,
		needs = { "scatter" },
	},
	{
		key = "d_skirmish",
		title = "Skirmishers",
		kind = "doctrine",
		icon = "d_skirmish",
		tagline = "A first-draft doctrine: quick feet",
		blurb = "Skirmishers can now come up in your first draft: attack +12%, regrowth +10%, defence -5%.",
		perks = { "FIRST DRAFT", "+12% ATTACK" },
		plain = "Your first draft may now offer Skirmishers: attack +12%, regrowth +10%, defence -5%.",
		facts = { "First draft", "Attack and regrowth" },
		stars = 5000,
		bit = Defs.UNLOCK.d_skirmish,
		opens = {},
		color = { 0xD8604A, 0x6A1E12 },
		branch = "war",
		row = 1,
		lane = 2,
		needs = {},
		doctrine = "skirmish",
	},
	{
		key = "d_siege",
		title = "Siege School",
		kind = "doctrine",
		icon = "d_siege",
		tagline = "A second-draft doctrine: walls into stone",
		blurb = "Siege School can now come up in your second draft: attack +12%, building refund +15%, gold -5%.",
		perks = { "SECOND DRAFT", "+15% REFUND" },
		plain = "Your second draft may now offer Siege School: attack +12%, building refund +15%, gold -5%.",
		facts = { "Second draft", "Attack and refunds" },
		stars = 12500,
		bit = Defs.UNLOCK.d_siege,
		opens = {},
		color = { 0xD8604A, 0x6A1E12 },
		branch = "war",
		row = 2,
		lane = 2,
		needs = { "d_skirmish" },
		doctrine = "siege",
	},
	{
		key = "d_praetorian",
		title = "Praetorian Guard",
		kind = "doctrine",
		icon = "d_praetorian",
		tagline = "A third-draft doctrine with an edict: Fortify",
		blurb = "Praetorian Guard can now come up in your third draft: defence +20%, attack +15%, gold -15%, and the Fortify edict.",
		perks = { "THIRD DRAFT", "EDICT: FORTIFY" },
		plain = "Your third draft may now offer Praetorian Guard: defence +20%, attack +15%, gold -15%. Edict: Fortify.",
		facts = { "Third draft", "Edict: Fortify" },
		stars = 25000,
		bit = Defs.UNLOCK.d_praetorian,
		opens = {},
		color = { 0xD8604A, 0x6A1E12 },
		branch = "war",
		row = 3,
		lane = 2,
		needs = { "d_siege", "mega" },
		doctrine = "praetorian",
	},
} :: { Item }

local BY_KEY: { [string]: Item } = {}
--- build / launch kind -> the item that opens it
local BY_KIND: { [string]: Item } = {}
for _, it in Arsenal.ITEMS do
	BY_KEY[it.key] = it
	for _, k in it.opens do
		BY_KIND[k] = it
	end
end

function Arsenal.item(key: any): Item?
	return if type(key) == "string" then BY_KEY[key] else nil
end

--- The item a build / launch kind ("artillery", "mega", "airstrike", "reinforce"...) belongs to, or nil
--- for the kinds everyone has.
function Arsenal.item_for(kind: string): Item?
	return BY_KIND[kind]
end

--- The Defs.UNLOCK mask of a set of unlock keys ({ [key] = true } or a list of keys).
function Arsenal.mask(unlocks: any): number
	local m = 0
	if type(unlocks) ~= "table" then
		return m
	end
	for k, v in unlocks do
		local it = BY_KEY[if type(k) == "string" then k else v]
		if it ~= nil and (v == true or type(k) == "number") then
			m = bit32.bor(m, it.bit)
		end
	end
	return m
end

--- A branch's items, top of the tree first.
function Arsenal.in_branch(branch: string): { Item }
	local out = {}
	for _, it in Arsenal.ITEMS do
		if it.branch == branch then
			table.insert(out, it)
		end
	end
	table.sort(out, function(a, b)
		return if a.row ~= b.row then a.row < b.row else a.lane < b.lane
	end)
	return out
end

--- What `it` still needs before Renown can buy it: the items, none when it is open. `owned`: { [key] = true }.
function Arsenal.missing(it: Item, owned: any): { Item }
	local out = {}
	for _, k in it.needs do
		if type(owned) ~= "table" or owned[k] ~= true then
			table.insert(out, BY_KEY[k])
		end
	end
	return out
end

--- The Renown the whole tree costs.
function Arsenal.total_stars(): number
	local n = 0
	for _, it in Arsenal.ITEMS do
		n += it.stars or 0
	end
	return n
end

return Arsenal
