--!strict
-- The Standards: a standing armoury, not a shelf that turns over. Every Standard is sold under one of the four ages
-- (a flag's `set` in Assets/ShopFlags), always at its rarity's price, and each age can be bought whole for one price.
-- Nothing here has a clock: what a player sees today they can buy next month, so nothing pushes them to buy now.
-- They are cosmetics like the Spoils' Standards (Data/Cosmetics: item "shop_<key>", kind "flag"; the ids are saved), but
-- never in Spoils and never on a bot player.
--
-- A receipt grants whenever it comes (server/Purchases); one already owned pays Renown instead.
local IS_ROBLOX = typeof(game) == "Instance"
local ShopFlags: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Assets.ShopFlags)
	else require("../Assets/ShopFlags")

local Shop = {}

--- Robux by rarity (each Standard's product is created at its rarity's price: docs/RELEASE_CHECKLIST.md).
Shop.PRICES = { rare = 35, epic = 69, legendary = 119 }
--- Renown for each Robux of something paid for twice, held already, or barred where it was bought (server/Purchases;
--- the Banners' TAKE AS RENOWN shows it too): about the middle of the War College's Renown-to-Robux prices, which run from
--- about 100 to 390 per Robux since they were halved for release (2026-11-07; it was 500 against 200-780).
Shop.RENOWN_PER_ROBUX = 250
--- The item id prefix (Data/Cosmetics).
Shop.ITEM_PREFIX = "shop_"

--- The ages they are sold under; `bundle`: the Robux of the whole age at once (its product: Assets/ShopFlags `sets`).
Shop.SETS = {
	dawn = { name = "Dawn", order = 1, line = "Beasts and house marks, from before the first war.", bundle = 349 },
	expansion = { name = "Expansion", order = 2, line = "Sails and far horizons.", bundle = 319 },
	conflict = { name = "Conflict", order = 3, line = "Storm, fire and things that creep.", bundle = 239 },
	reckoning = { name = "Reckoning", order = 4, line = "For a ruler with nothing left to lose.", bundle = 349 },
}

type Flag = { key: string, name: string, rarity: string, set: string?, [string]: any }

local flags: { Flag } = {}
local by_key: { [string]: Flag } = {}
for _, f in (ShopFlags.flags or {}) :: { any } do
	table.insert(flags, f)
	by_key[f.key] = f
end

function Shop.flags(): { Flag }
	return flags
end

function Shop.flag(key: any): Flag?
	return if type(key) == "string" then by_key[key] else nil
end

function Shop.price(f: any): number
	return Shop.PRICES[f and f.rarity or ""] or Shop.PRICES.rare
end

function Shop.item_id(key: string): string
	return Shop.ITEM_PREFIX .. key
end

--- The Standard's key of item id `id` (nil: not one of these).
function Shop.key_of(id: any): string?
	if type(id) ~= "string" or string.sub(id, 1, #Shop.ITEM_PREFIX) ~= Shop.ITEM_PREFIX then
		return nil
	end
	local key = string.sub(id, #Shop.ITEM_PREFIX + 1)
	return if by_key[key] ~= nil then key else nil
end

--- The keys of age `id`, rarest first, then by name.
function Shop.set_keys(id: string): { string }
	local keys = {}
	for _, f in flags do
		if f.set == id then
			table.insert(keys, f.key)
		end
	end
	local rank = { legendary = 1, epic = 2, rare = 3 }
	table.sort(keys, function(a, b)
		local fa, fb = by_key[a], by_key[b]
		local ra, rb = rank[fa.rarity] or 9, rank[fb.rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		return fa.name < fb.name
	end)
	return keys
end

--- The ages in order: { { id, name, line, keys } }.
function Shop.ages(): { any }
	local out = {}
	for id, s in Shop.SETS do
		table.insert(out, { id = id, name = s.name, line = s.line, order = s.order, keys = Shop.set_keys(id) })
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

--- Age `id`'s bundle product ids: (production, Rofront Staging); 0 = not made yet.
function Shop.bundle_ids(id: string): (number, number)
	local s = (ShopFlags.sets or {})[id]
	return if s then s.product or 0 else 0, if s then s.staging or 0 else 0
end

--- Age `id`'s Standards bought one by one (Robux).
function Shop.set_total(id: string): number
	local n = 0
	for _, k in Shop.set_keys(id) do
		n += Shop.price(by_key[k])
	end
	return n
end

return Shop
