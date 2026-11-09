--!strict
-- The Founding Grant: once, a ruler chooses what their nation is founded on, one branch of the War College (Data/Arsenal).
-- Each founding is its own developer product (Data/Products), so the receipt itself says which was chosen; that is the
-- whole of the choice, and it can't be lost between the prompt and the receipt.
--
-- There is no clock and it never opens by itself: it stands on the title's row until it is taken. It sells unlocks
-- worth `Starter.worth` Renown for one price, and says exactly that; there is no struck-through "regular" price, because
-- the bundle has none. Its receipt always grants (server/Purchases): an item already held pays its Renown price, and a
-- second founding (two servers, a tampered client) pays its Robux in Renown. Old saves keep `starter.used`; an old
-- `started` and `ends` mean nothing now.
local IS_ROBLOX = typeof(game) == "Instance"
local Catalog: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Arsenal)
	else require("./Arsenal")

local Starter = {}

--- The foundings, in the War College's branch order. `renown` is paid with the items. (Each is worth 30,000 at the War
--- College's Renown prices since those were halved for release, 2026-11-07; it was 45,000 at the old prices.)
Starter.FOUNDINGS = {
	{
		key = "expansion",
		product = "starter_expansion",
		title = "Founded on Land",
		line = "Claim early, raise troops when it counts.",
		icon = "land",
		items = { "reinforce", "d_homestead" },
		renown = 12500,
	},
	{
		key = "economy",
		product = "starter_economy",
		title = "Founded on Gold",
		line = "Every new age pays a minute of your income.",
		icon = "gold",
		items = { "stars2x", "d_customs" },
		renown = 10000,
	},
	{
		key = "war",
		product = "starter_war",
		title = "Founded on Iron",
		line = "Long Guns the moment the Conflict opens.",
		icon = "iron",
		items = { "artillery", "d_skirmish" },
		renown = 10000,
	},
}

local BY_KEY: { [string]: any } = {}
for _, f in Starter.FOUNDINGS do
	BY_KEY[f.key] = f
end

function Starter.founding(key: any): any
	return if type(key) == "string" then BY_KEY[key] else nil
end

--- What founding `f` is worth at the War College's Renown prices: its items, what they pay on unlocking, its own Renown.
function Starter.worth(f: any): number
	local n = f.renown
	for _, k in f.items do
		local it = Catalog.item(k)
		n += (it.stars or 0) + (it.bonus or 0)
	end
	return n
end

--- Every War College key any founding unlocks (a tester's "Replay as new player" takes these back).
function Starter.all_items(): { string }
	local out = {}
	for _, f in Starter.FOUNDINGS do
		for _, k in f.items do
			table.insert(out, k)
		end
	end
	return out
end

--- May the ruler with `unlocks` still gain anything from founding `f`?
function Starter.useful(f: any, unlocks: any): boolean
	for _, k in f.items do
		if type(unlocks) ~= "table" or unlocks[k] ~= true then
			return true
		end
	end
	return false
end

return Starter
