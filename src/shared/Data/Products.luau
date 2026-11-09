--!strict
-- Robux developer products (Creator Dashboard → Monetization → Developer Products). `id` is the
-- product's id; 0 = not created yet (its offer stays hidden). Each purchase is a saved credit of kind
-- `grants` (default: the key), `count` of them (default 1) (server/Purchases.luau): bought credits are
-- never lost if the moment passes. A `grants` of "unlock:<key>" is not a credit: it unlocks that
-- Arsenal item for good (Data/Arsenal).
--
-- Product ids belong to one experience. `staging` is the same product in Rofront Staging (2026-10-04:
-- a separate experience where a build is tested before it goes to prod); in that experience it
-- replaces `id`. Create or reprice them with
-- tools/assets/make_products.py.
local PRODUCTS: { [string]: any } = {
	--- Solo / public: take over the AI nation that eliminated you (2026-09-28).
	takeover = { id = 3729594150, robux = 29, staging = 0 },
	--- One dispatch of Spoils (Data/Cosmetics). Why these numbers: research_notes VOCAB.md, "Prices".
	crate = { id = 3729594157, robux = 45, staging = 0 },
	--- The first dispatch a player buys (offered only before their first).
	crate_first = { id = 3729594161, robux = 19, grants = "crate", first_only = true, staging = 0 },
	--- A satchel of four, and a courier's load of nine: `count` credits for one receipt.
	crate_satchel = { id = 3729594167, robux = 150, grants = "crate", count = 4, staging = 0 },
	crate_courier = { id = 3729594175, robux = 295, grants = "crate", count = 9, staging = 0 },
	--- The War College (Data/Arsenal).
	unlock_mega = { id = 3729594184, robux = 45, grants = "unlock:mega", staging = 0 },
	unlock_scatter = { id = 3729594195, robux = 75, grants = "unlock:scatter", staging = 0 },
	unlock_reinforce = { id = 3729594202, robux = 129, grants = "unlock:reinforce", staging = 0 },
	unlock_artillery = { id = 3729594210, robux = 89, grants = "unlock:artillery", staging = 0 },
	unlock_airfield = { id = 3729594219, robux = 299, grants = "unlock:airfield", staging = 0 },
	unlock_railgun = { id = 3729594224, robux = 799, grants = "unlock:railgun", staging = 0 },
	unlock_stars2x = { id = 3729594229, robux = 69, grants = "unlock:stars2x", staging = 0 },
	unlock_reload2x = { id = 3729594238, robux = 119, grants = "unlock:reload2x", staging = 0 },
	--- The Founding Grant (Data/Starter): one product per founding, the ruler buys the one they choose, once.
	starter_expansion = { id = 3729594246, robux = 55, grants = "starter:expansion", staging = 0 },
	starter_economy = { id = 3729594251, robux = 55, grants = "starter:economy", staging = 0 },
	starter_war = { id = 3729594260, robux = 55, grants = "starter:war", staging = 0 },
}

--- The Standards (Data/Shop): one product per Standard, made by hand (docs/RELEASE_CHECKLIST.md; the ids live in
--- Assets/ShopFlags), each granting "shopflag:<key>".
--- `shop_flag` marks them: UI/Prices asks Roblox for these only when the shop shows them.
local Shop: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.Shop)
	else (require :: any)("./Shop")
for _, f in Shop.flags() do
	PRODUCTS["shop_" .. f.key] = {
		id = f.product or 0,
		robux = Shop.price(f),
		grants = "shopflag:" .. f.key,
		staging = f.staging or 0,
		shop_flag = f.key,
	}
end

--- An age's bundle (Data/Shop.SETS `bundle`): all its Standards in one product, granting
--- "shopset:<id>".
for sid, s in Shop.SETS do
	if s.bundle ~= nil then
		local prod, staging = Shop.bundle_ids(sid)
		PRODUCTS["shopset_" .. sid] = {
			id = prod,
			robux = s.bundle,
			grants = "shopset:" .. sid,
			staging = staging,
			shop_set = sid,
		}
	end
end

--- Rofront Staging (Data/Staging): there every product is its `staging` one.
local Staging: any = if typeof(game) == "Instance"
	then require((script :: any).Parent.Staging)
	else (require :: any)("./Staging")

if Staging.here() then
	for _, p in PRODUCTS do
		p.id = p.staging or 0
	end
end

return PRODUCTS
