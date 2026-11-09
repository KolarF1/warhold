--!strict
-- Patterns and Standards, and the Spoils that carry them: a sealed dispatch from the front, opened for one thing you don't
-- have yet (never a repeat; paid only; server/Purchases.open_crate). Internal names stay: a Pattern is a skin, a Standard
-- a flag, Spoils a crate, and the rarity ids are saved words.
--
--   skins   a territory pattern: a 1-bit mask tiled over your land (primary vs
--           secondary tiles; mask pixels are 2^scale tiles wide). '#' = the secondary colour: your
--           own colour lightened (tone > 0) or darkened (tone < 0), or a fixed `accent` colour
--           (legendary skins). Original designs.
--   flags   country flags (Assets/Flags, public domain from Wikimedia Commons), shown by your
--           name on the map and the leaderboard. Every flag is Common.
--   exclusive skins (exclusive_skins) are made for particular players: several colours, never in a
--           crate (Cosmetics.all() is the crate catalog; Cosmetics.exclusives() these).
--   shop flags (Data/Shop: "shop_<key>") are bought one by one in the flag shop: Rare, Epic or
--           Legendary, never in a crate nor on a bot player, not in the Locker's "N of M"
--           (Cosmetics.shop_items()).
--
-- Spoils roll a rarity by RARITIES odds, then an item of that rarity the player doesn't own yet
-- (uniformly); rarities with nothing left drop out and the odds of the rest scale up (odds() gives
-- the player's own odds, shown before every purchase — Roblox's paid random items rules). With nothing left to find, a
-- dispatch pays SPOILS_RENOWN instead, so no paid outcome is ever empty; may_buy stops a sale that could only do that.
local IS_ROBLOX = typeof(game) == "Instance"
local Flags: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Assets.Flags)
	else require("../Assets/Flags")
local ShopFlags: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Assets.ShopFlags)
	else require("../Assets/ShopFlags")
local Shop: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Shop)
	else require("./Shop")

local Cosmetics = {}

--- The size of a flag as the name tags, lists and the Locker show it, and as the shop's cards show it.
Cosmetics.FLAG_W = 57 -- (half the upstream's: the emblems are drawn on the device, and every pixel is EditableImage memory)
Cosmetics.FLAG_H = 38
Cosmetics.FLAG_BIG_W = 114
Cosmetics.FLAG_BIG_H = 76
--- The shop's featured card is drawn twice as big again (one image, not thirty).
Cosmetics.FLAG_HERO_W = 228
Cosmetics.FLAG_HERO_H = 152

Cosmetics.RARITIES = {
	-- (the ids are saved words; the colours are UITheme.RARITY's: ash, laurel, rose, ember)
	{ id = "common", name = "Issued", odds = 0.58, color = 0xB0AA9C },
	{ id = "rare", name = "Honoured", odds = 0.27, color = 0x6EBE8C },
	{ id = "epic", name = "Storied", odds = 0.11, color = 0xD870A0 },
	{ id = "legendary", name = "Mythic", odds = 0.04, color = 0xEE783E },
}

--- What a dispatch pays when there is nothing left to find (a pack's last ones, a sale that raced the collection).
-- (about a dispatch's Robux at Data/Shop.RENOWN_PER_ROBUX, rounded: it was 20,000 before the War College's prices were halved)
Cosmetics.SPOILS_RENOWN = 12000

--- (mask rows top to bottom; every row the same width)
Cosmetics.skins = {
	-- The cartographers' batch
	{ id = "contour", name = "Contour", rarity = "common", scale = 0, tone = -0.22, mask = { "..####..", ".#....#.", "#..##..#", ".#....#.", "..####.." } },
	{ id = "gridref", name = "Grid Reference", rarity = "common", scale = 0, tone = -0.2, mask = { "#.......", "#.......", "#.......", "########" } },
	{ id = "hachure", name = "Hachure", rarity = "common", scale = 0, tone = -0.22, mask = { "#.#.#.#.", "........", ".#.#.#.#", "........" } },
	{ id = "dunes", name = "Dunes", rarity = "common", scale = 0, tone = 0.24, mask = { "##......", "..##....", "....##..", "......##", "....##..", "..##...." } },
	{ id = "fields", name = "Fields", rarity = "common", scale = 1, tone = -0.16, mask = { "##..", "##..", "..##", "..##" } },
	{ id = "shoal", name = "Shoal", rarity = "rare", scale = 0, tone = 0.28, mask = { "#...#...", "...#...#", ".#...#..", "#...#..." } },
	{ id = "compass", name = "Compass", rarity = "rare", scale = 0, tone = -0.28, mask = { "...#....", "...#....", "..###...", "#######.", "..###...", "...#....", "...#....", "........" } },
	{ id = "terraces", name = "Terraces", rarity = "rare", scale = 0, tone = -0.26, mask = { "########", "........", "...#####", "........", "#####...", "........" } },
	{ id = "rampart", name = "Rampart", rarity = "rare", scale = 0, tone = -0.3, mask = { "##..##..", "##..##..", "########", "########" } },
	{ id = "lattice", name = "Lattice", rarity = "epic", scale = 0, tone = -0.28, mask = { "#..#..#.", ".##.##..", "#..#..#.", "..#..#..", ".#.##.#.", "..#..#.." } },
	{ id = "meridian", name = "Meridian", rarity = "epic", scale = 0, tone = 0.3, mask = { "#...#...", "#...#...", "#...#...", "########", "#...#...", "#...#..." } },
	{ id = "stormfront", name = "Stormfront", rarity = "epic", scale = 0, tone = -0.3, mask = { "#.....#.", ".#...#..", "..#.#...", "...#....", "..#.#...", ".#...#..", "#.....#." } },
	{ id = "atlas", name = "Atlas", rarity = "legendary", scale = 0, accent = 0x3DE0CE, mask = { "..####..", ".#.##.#.", "#..##..#", "########", "#..##..#", ".#.##.#.", "..####.." } },
	{ id = "seafarer", name = "Seafarer", rarity = "legendary", scale = 0, accent = 0xFFC24A, mask = { "...##...", "...##...", ".######.", "...##...", "#..##..#", ".#.##.#.", "..####.." } },
	-- The older ids, drawn again from what each name means; the ids stay because saves use them
	{
		id = "stripes",
		name = "Palisade",
		rarity = "common",
		scale = 0,
		tone = -0.22,
		mask = {
			".#...#..",
			"###.###.",
			"###.###.",
			"###.###.",
			"###.###.",
			"........",
		},
	},
	{
		id = "bands",
		name = "Strata",
		rarity = "common",
		scale = 1,
		tone = -0.22,
		mask = {
			"######",
			"......",
			"..####",
			"......",
			"####..",
			"######",
			"......",
		},
	},
	{
		id = "checker",
		name = "Quarters",
		rarity = "common",
		scale = 0,
		tone = -0.18,
		mask = {
			"####....",
			"####....",
			"###.....",
			"###.....",
			"....####",
			"....####",
			".....###",
			".....###",
		},
	},
	{ id = "diagonal", name = "Slant", rarity = "common", scale = 1, tone = -0.24, mask = { "##......", "...##...", "......##", "........" } },
	{
		id = "dots",
		name = "Rivets",
		rarity = "common",
		scale = 0,
		tone = 0.32,
		mask = {
			"........",
			".#..#...",
			"........",
			"........",
			"#....#..",
			"........",
		},
	},
	{
		id = "cobble",
		name = "Fieldstone",
		rarity = "common",
		scale = 0,
		tone = -0.24,
		mask = {
			".###..##..",
			"#...##..#.",
			"#...#....#",
			".###.#...#",
			"..#...###.",
			".#.#...#..",
			"#...#.#.#.",
			".###...#..",
		},
	},
	{
		id = "grid",
		name = "Survey",
		rarity = "rare",
		scale = 0,
		tone = -0.26,
		mask = {
			"..#...",
			"..#...",
			"#####.",
			"..#...",
			"..#...",
			"......",
		},
	},
	{
		id = "bricks",
		name = "Masonry",
		rarity = "rare",
		scale = 0,
		tone = -0.3,
		mask = {
			"############",
			"....#.......",
			"....#.......",
			"############",
			".........#..",
			"############",
			"..#.....#...",
			"..#.....#...",
			"..#.....#...",
		},
	},
	{
		id = "waves",
		name = "Swell",
		rarity = "rare",
		scale = 0,
		tone = -0.24,
		mask = {
			"..####..",
			".#....#.",
			"#......#",
			"........",
			"##....##",
			"..#..#..",
			"...##...",
			"........",
		},
	},
	{
		id = "crosshatch",
		name = "Hatchwork",
		rarity = "rare",
		scale = 0,
		tone = -0.24,
		mask = {
			"#.#.#...",
			"#.#.#.##",
			"#.#.#...",
			"......##",
			"###.....",
			"....#.#.",
			"###.#.#.",
			"....#.#.",
		},
	},
	{
		id = "hex",
		name = "Comb",
		rarity = "rare",
		scale = 0,
		tone = -0.26,
		mask = {
			"..####..",
			".#....#.",
			"#......#",
			"#......#",
			".#....#.",
			"..####..",
			"...##...",
			"...##...",
		},
	},
	{
		id = "tartan",
		name = "Weave",
		rarity = "rare",
		scale = 0,
		tone = -0.22,
		mask = {
			"###.#.#.",
			"###.#.#.",
			"###.#.#.",
			"........",
			"#.#.###.",
			"#.#.###.",
			"#.#.###.",
			"........",
		},
	},
	{
		id = "diamonds",
		name = "Facets",
		rarity = "epic",
		scale = 0,
		tone = -0.26,
		mask = {
			"#.......",
			"##......",
			"###.....",
			"####....",
			"#####...",
			"######..",
			"#######.",
			"########",
		},
	},
	{ id = "zigzag", name = "Sawtooth", rarity = "epic", scale = 1, tone = -0.3, mask = { "#.....", "##....", "###...", "######" } },
	{
		id = "stars",
		name = "Nightfall",
		rarity = "epic",
		scale = 0,
		tone = 0.42,
		mask = {
			"............",
			"...##.......",
			"..##.....#..",
			"..##........",
			"...##.......",
			"............",
			".........#..",
			".#..........",
			"......#.....",
			"............",
		},
	},
	{
		id = "camo",
		name = "Thicket",
		rarity = "epic",
		scale = 1,
		tone = -0.3,
		mask = {
			"#.....#.....",
			".#...#......",
			"..#.#...#...",
			"...#...#....",
			"...#..#...#.",
			"...#.#...#..",
			"....#...#...",
			"....#..#....",
			"#...#.#.....",
			".#..##......",
			"..#.#.......",
			"...##.......",
		},
	},
	{
		id = "circuit",
		name = "Conduit",
		rarity = "epic",
		scale = 0,
		tone = 0.34,
		mask = {
			"###.......",
			"..#..###..",
			"..#..#.#..",
			"..####.###",
			".....#.#..",
			"####.###..",
			"...#......",
			"...#......",
		},
	},
	{
		id = "gilded",
		name = "Imperial Crowns",
		rarity = "legendary",
		scale = 0,
		accent = 0x8C3FD1,
		mask = {
			"..........",
			"#...#...#.",
			"##.###.##.",
			"#########.",
			"#########.",
			"..........",
			".#.#.#.#..",
			"..........",
		},
	},
	{
		id = "frost",
		name = "Aurora",
		rarity = "legendary",
		scale = 0,
		accent = 0x3CF0A0,
		mask = {
			"....#.....",
			"..#.#.#...",
			"...###....",
			"#...#...#.",
			".#..#..#..",
			"..#.#.#...",
			"...###....",
			"....#.....",
			"....#.....",
			"..........",
		},
	},
	{
		id = "obsidian",
		name = "Cobalt Shards",
		rarity = "legendary",
		scale = 0,
		accent = 0x1E6FD9,
		mask = {
			"#.........",
			"##.....#..",
			"###...##..",
			".###.###..",
			"..#####...",
			"...###....",
			"....#....#",
			"#.......##",
			"##.....##.",
			".##...##..",
		},
	},
	{
		id = "ember",
		name = "Thornrose",
		rarity = "legendary",
		scale = 0,
		accent = 0xD81E8A,
		mask = {
			"...#....",
			"........",
			".#...#..",
			"........",
			"...#....",
			"..###...",
			".#####..",
			".##.##..",
			"..#.#...",
			"........",
		},
	},
}

--- Skins made for one player (none yet). Never in a crate, never on a
--- bot player, not in the Locker's "N of M": the `owners` (Roblox user ids) own them (Purchases), and it
--- goes on the first time they join with it. Several colours: in `mask`, '.' is the owner's own fill and
--- '1'..'9', 'a'..'z' are colors[1..], drawn at `alpha`.
Cosmetics.exclusive_skins = {
}

--- How an exclusive item shows in the Locker (not a crate rarity: no odds).
Cosmetics.EXCLUSIVE = { id = "exclusive", name = "Bespoke", odds = 0, color = 0x80B0E8 }

--- The Charter's Pattern (Data/Subscription), which a holder keeps. Never in Spoils nor on a bot player, not in the
--- Banners' "N of M"; only
--- server/Purchases.general_perks gives one, and anyone given one may own it. Several colours, as an
--- exclusive's.
Cosmetics.general_skins = {
	{
		-- a cord: two strands twisted together, in sea green and bone, a broad gap between
		id = "gen_chevrons",
		name = "Charter Braid",
		scale = 0,
		alpha = 185,
		colors = { 0x2FA89A, 0xF0E6C8 },
		mask = { "12121212", "21212121", "........", "........", "........", "........", "12121212", "21212121" },
	},
}
--- How the Charter's Pattern shows in the Banners.
Cosmetics.GENERAL = { id = "general", name = "Charter", odds = 0, color = 0xC4B48C }

--- Alpha of the secondary tiles (the primary fill is MapSurface.TERRITORY_ALPHA, 150).
Cosmetics.SECONDARY_ALPHA = 190

type Item = { id: string, kind: string, name: string, rarity: string, [string]: any }

local items: { [string]: Item } = {}
local order: { Item } = {}
for _, s in Cosmetics.skins do
	local it: any = table.clone(s)
	it.kind = "skin"
	items[it.id] = it
	table.insert(order, it)
end
for _, f in (Flags.flags or {}) :: { any } do
	local it: any = table.clone(f)
	it.id = "flag_" .. f.code
	it.kind = "flag"
	it.rarity = "common"
	it.emblem = f.code -- (Art/Emblem draws the flag from this key)
	it.x, it.y, it.w, it.h = 0, 0, Cosmetics.FLAG_W, Cosmetics.FLAG_H
	items[it.id] = it
	table.insert(order, it)
end
-- (exclusives resolve by id like any item, but stay out of `order`: the crates, their odds, bot players)
local exclusives: { Item } = {}
local granted: { [number]: { string } } = {}
--- Makes `s` an exclusive skin (an entry of exclusive_skins, or a test's own).
function Cosmetics.add_exclusive(s: any)
	local it: any = table.clone(s)
	it.kind = "skin"
	it.rarity = "exclusive"
	it.exclusive = true
	items[it.id] = it
	table.insert(exclusives, it)
	for _, uid in s.owners or {} do
		granted[uid] = granted[uid] or {}
		table.insert(granted[uid], it.id)
	end
end
for _, s in Cosmetics.exclusive_skins do
	Cosmetics.add_exclusive(s)
end

-- (General skins resolve by id too, and stay out of `order` like the exclusives)
local generals: { Item } = {}
for _, g in Cosmetics.general_skins do
	local it: any = table.clone(g)
	it.kind = "skin"
	it.rarity = "general"
	it.general = true
	items[it.id] = it
	table.insert(generals, it)
end

-- (shop flags resolve by id too, and stay out of `order` like the exclusives)
local shop_items: { Item } = {}
for _, f in Shop.flags() do
	local it: any = {
		id = Shop.item_id(f.key),
		kind = "flag",
		shop = true,
		key = f.key,
		name = f.name,
		rarity = f.rarity,
		set = f.set,
		emblem = f.key,
		x = 0,
		y = 0,
		w = Cosmetics.FLAG_W,
		h = Cosmetics.FLAG_H,
	}
	items[it.id] = it
	table.insert(shop_items, it)
end

-- The catalog's order, which every list and the Details window show: Mythic down to Issued, Patterns before Standards,
-- then by name. Nothing saved depends on it.
local RANK = { legendary = 1, epic = 2, rare = 3, common = 4 }
table.sort(order, function(a: Item, b: Item): boolean
	if a.kind ~= b.kind then
		return a.kind == "skin"
	end
	if a.rarity ~= b.rarity then
		return RANK[a.rarity] < RANK[b.rarity]
	end
	return a.id < b.id
end)

--- A country's Standard bought outright with Renown (release 2026-11-07): free players' way to fly their own flag, and
--- what Renown buys once the War College is done. Only the plain country flags (Issued): never a Pattern, never a rarer
--- Standard, never random, so it stays apart from Spoils and the paid Standards.
Cosmetics.RENOWN_FLAG_PRICE = 6000

--- What `it` costs in Renown, or nil when Renown can't buy it.
function Cosmetics.renown_price(it: any): number?
	if type(it) ~= "table" or it.kind ~= "flag" or it.rarity ~= "common" or it.shop or it.exclusive or it.general then
		return nil
	end
	if type(it.id) ~= "string" or string.sub(it.id, 1, 5) ~= "flag_" then
		return nil
	end
	return Cosmetics.RENOWN_FLAG_PRICE
end

function Cosmetics.item(id: any): Item?
	return if type(id) == "string" then items[id] else nil
end

--- Every item Spoils can hold (Patterns first, rarest first). Exclusives are not in it (Cosmetics.exclusives).
function Cosmetics.all(): { Item }
	return order
end

--- The items made for particular players (Cosmetics.exclusive_skins).
function Cosmetics.exclusives(): { Item }
	return exclusives
end

--- The Charter's Patterns (Cosmetics.general_skins), as items.
function Cosmetics.generals(): { Item }
	return generals
end

--- The flag shop's flags (Data/Shop), as items.
function Cosmetics.shop_items(): { Item }
	return shop_items
end

--- The exclusive item ids made for Roblox user `user_id` (empty for everyone else).
function Cosmetics.granted(user_id: any): { string }
	return if type(user_id) == "number" then (granted[user_id] or {}) else {}
end

--- May user `user_id` own item `id`? Any crate item; an exclusive only for its owners.
function Cosmetics.may_own(id: any, user_id: any): boolean
	local it = Cosmetics.item(id)
	if it == nil then
		return false
	end
	if not it.exclusive then
		return true
	end
	for _, g in Cosmetics.granted(user_id) do
		if g == id then
			return true
		end
	end
	return false
end

--- How many crate items a set of owned ids holds (the Locker's "N of M"; exclusives and shop flags
--- don't count).
function Cosmetics.crate_owned(owned: { [string]: any }): number
	local n = 0
	for id in owned do
		local it = items[id]
		if it ~= nil and not it.exclusive and not it.shop and not it.general then
			n += 1
		end
	end
	return n
end

function Cosmetics.rarity(id: string): any
	if id == "exclusive" then
		return Cosmetics.EXCLUSIVE
	elseif id == "general" then
		return Cosmetics.GENERAL
	end
	for _, r in Cosmetics.RARITIES do
		if r.id == id then
			return r
		end
	end
	return Cosmetics.RARITIES[1]
end

--- The flag atlas image of a flag item (its x, y, w, h: the rect in it).
--- A flag's picture: a descriptor the client turns into an image on first use (Art/Registry, UI/FlagArt). The flag is
--- drawn from its key (Art/Emblem), so it is always the whole image: the rect is (0, 0, it.w, it.h).
function Cosmetics.flag_image(it: any): any
	if it == nil or it.emblem == nil then
		return ""
	end
	return { art = true, kind = "flag", key = it.emblem, w = Cosmetics.FLAG_W, h = Cosmetics.FLAG_H }
end

--- A flag item at the shop card's size: (image, x, y, w, h), the same emblem drawn bigger; `hero`: the featured card's
--- size, twice again.
function Cosmetics.flag_big(it: any, hero: boolean?): (any, number, number, number, number)
	if it == nil or it.emblem == nil then
		return "", 0, 0, 0, 0
	end
	local w = if hero then Cosmetics.FLAG_HERO_W else Cosmetics.FLAG_BIG_W
	local h = if hero then Cosmetics.FLAG_HERO_H else Cosmetics.FLAG_BIG_H
	return { art = true, kind = "flag", key = it.emblem, w = w, h = h }, 0, 0, w, h
end

--- A player's Roblox head shot: the `face` of a match's cosmetics map is their user id (since
--- 2026-10-04 a little Roblox head picture shows next to each username).
--- What goes beside a name: above 0 a person's own head shot; below 0 a bot player, whose picture is a made-up
--- avatar (Data/BotLooks, drawn by UI/BotPortrait, never a real account's): no image here (2026-11-02; it was a
--- commander badge drawn with the flag art).
function Cosmetics.face_image(face: number): any
	if face < 0 then
		return ""
	end
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", face)
end

--- A bot player's look number (Data/BotLooks) from a `face`, or nil for a person (or no face).
function Cosmetics.bot_look(face: number?): number?
	if type(face) == "number" and face < 0 then
		return -face
	end
	return nil
end

--- The player's own odds per rarity: RARITIES' odds over the rarities that still have an item they
--- don't own (owned: set of item ids). { {rarity, odds, left} } in RARITIES order; odds sum to 1 (0 each
--- when everything is owned).
function Cosmetics.odds(owned: { [string]: any }): { { rarity: any, odds: number, left: number } }
	local out = {}
	local total = 0.0
	for _, r in Cosmetics.RARITIES do
		local left = 0
		for _, it in order do
			if it.rarity == r.id and not owned[it.id] then
				left += 1
			end
		end
		table.insert(out, { rarity = r, odds = if left > 0 then r.odds else 0.0, left = left })
		if left > 0 then
			total += r.odds
		end
	end
	for _, e in out do
		e.odds = if total > 0 then e.odds / total else 0.0
	end
	return out
end

--- The player's odds of each item a crate can still give: a rarity's odds shared evenly among its items
--- they don't own (what roll does). { {item, rarity, odds} } in RARITIES order, then catalog order.
function Cosmetics.item_odds(owned: { [string]: any }): { { item: any, rarity: any, odds: number } }
	local out = {}
	for _, e in Cosmetics.odds(owned) do
		if e.left > 0 then
			for _, it in order do
				if it.rarity == e.rarity.id and not owned[it.id] then
					table.insert(out, { item = it, rarity = e.rarity, odds = e.odds / e.left })
				end
			end
		end
	end
	return out
end

--- How many items Spoils can still give this player.
function Cosmetics.left(owned: { [string]: any }): number
	return #order - Cosmetics.crate_owned(owned)
end

--- May `n` more Spoils be sold now? Only where paid random items are allowed (`allowed`, PolicyService: anything but true
--- is no), and only while every one of them, with the `waiting` already bought, still has something new to find.
function Cosmetics.may_buy(owned: { [string]: any }, waiting: number, n: number, allowed: any): boolean
	return allowed == true and Cosmetics.left(owned) - math.max(waiting, 0) >= math.max(n, 1)
end

--- Roblox's wording for rounded odds (paid random items policy).
Cosmetics.ODDS_ROUNDED_NOTE = "Probabilities are rounded; total of displayed individual probabilities may not equal 100%."

--- A probability (0..1) as a percentage: exact when it fits in two decimals, otherwise rounded to at
--- least four places below its first non-zero digit, as the policy asks. (text, was_rounded)
function Cosmetics.odds_text(p: number): (string, boolean)
	local v = p * 100
	local whole = math.floor(v * 100 + 0.5) / 100
	if math.abs(v - whole) < 1e-9 then
		local s = string.format("%.2f", whole)
		s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "")
		return s .. "%", false
	end
	local places = 4
	if v < 1 then
		-- (0.0123 has its first non-zero digit 2 places down: 2 + 4)
		places = math.ceil(-math.log10(v) - 1e-9) + 4
	end
	return string.format("%." .. tostring(places) .. "f%%", v), true
end

--- Roll a crate: an item the player doesn't own (nil when they own everything). r1, r2 in [0, 1).
function Cosmetics.roll(owned: { [string]: any }, r1: number, r2: number): string?
	local odds = Cosmetics.odds(owned)
	local x = r1
	local pick = nil
	for _, e in odds do
		if e.odds > 0 then
			pick = e
			if x < e.odds then
				break
			end
			x -= e.odds
		end
	end
	if pick == nil then
		return nil
	end
	local pool = {}
	for _, it in order do
		if it.rarity == pick.rarity.id and not owned[it.id] then
			table.insert(pool, it.id)
		end
	end
	return pool[math.clamp(math.floor(r2 * #pool) + 1, 1, #pool)]
end

--- The colour number of mask character `ch`: 0 for the owner's own fill ('.' or anything unknown), 1 for
--- '#' (a two-tone skin's secondary), '1'..'9' -> 1..9 and 'a'..'z' -> 10..35 (a skin's `colors`).
local function mask_key(ch: string): number
	if ch == "#" then
		return 1
	end
	local b = string.byte(ch)
	if b >= 49 and b <= 57 then -- '1'..'9'
		return b - 48
	elseif b >= 97 and b <= 122 then -- 'a'..'z'
		return b - 87
	end
	return 0
end

--- A skin's mask as a buffer of w * h bytes for MapSurface: 0 = the owner's fill, 1 = a two-tone skin's
--- secondary, or k = colors[k] of a skin with `colors`.
function Cosmetics.mask(skin: any): (buffer, number, number)
	local rows = skin.mask
	local h = #rows
	local w = 0
	for _, row in rows do
		w = math.max(w, #row)
	end
	local b = buffer.create(w * h)
	for y, row in rows do
		for x = 1, #row do
			buffer.writeu8(b, (y - 1) * w + (x - 1), mask_key(string.sub(row, x, x)))
		end
	end
	return b, w, h
end

--- colors[k] of a skin with several colours as (r, g, b) floats (nil past its list, or a two-tone skin).
function Cosmetics.color(skin: any, k: number): (number?, number?, number?)
	local list = skin.colors
	local c = if type(list) == "table" then list[k] else nil
	if type(c) ~= "number" then
		return nil, nil, nil
	end
	return ((c // 65536) % 256) / 255, ((c // 256) % 256) / 255, (c % 256) / 255
end

--- The alpha (0..255) a skin's own colours are drawn at.
function Cosmetics.skin_alpha(skin: any): number
	return if type(skin.alpha) == "number" then skin.alpha else Cosmetics.SECONDARY_ALPHA
end

--- The secondary colour (r, g, b floats) of `skin` over a territory of colour (r, g, b).
function Cosmetics.secondary(skin: any, r: number, g: number, b: number): (number, number, number)
	local a = skin.accent
	if type(a) == "number" then
		return ((a // 65536) % 256) / 255, ((a // 256) % 256) / 255, (a % 256) / 255
	end
	local t = tonumber(skin.tone) or -0.2
	if t >= 0 then
		return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
	end
	return r * (1 + t), g * (1 + t), b * (1 + t)
end

return Cosmetics
