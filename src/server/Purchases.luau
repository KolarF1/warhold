--!strict
-- Robux purchases (developer products, shared/Data/Products). A purchase is a saved credit: Roblox's
-- ProcessReceipt adds it to the player's record in its own DataStore (only the server writes it —
-- the client's SETTING op can't touch it) and only then reports the purchase granted, so Roblox
-- retries until it is stored and a receipt is never granted twice (its PurchaseId is kept). The game
-- spends a credit when the moment comes (Purchases.use); one bought after the moment passed stays
-- for the next time.
--
--   Purchases.configure(deps)     { datastore = DataStore, notify = fn(player, credits), log? }
--   Purchases.process_receipt(info) -> "granted" | "not_processed"   (a product's `count` credits)
--   Purchases.load(player)        read the record (join; retried while Roblox refuses it); notify
--   Purchases.credits(player) -> { [kind]: number }
--   Purchases.use(player, kind) -> (ok, err?)   spend one (yields)
--   Purchases.release(player)     PlayerRemoving
--   Purchases.open_crate(player) -> (ok, item_id | "renown" | err, renown?)   spend a credit: an item, or Renown if none is left
--   Purchases.read_policy(ok, info) -> { crates = true | false | nil, charter = boolean }   PolicyService's answer
--   Purchases.equip(player, slot, id | false) -> (ok, err?)   "skin" / "flag"; only owned items
--   Purchases.inventory(player) -> { owned = { id }, equipped = { skin?, flag? }, crates_bought,
--                                    stars, unlocks = { key } }
--   Purchases.add_stars(player, amount) -> (ok, balance)   a match's Stars (Data/Stars; yields)
--   Purchases.buy_unlock(player, key) -> (ok, err?)        unlock a War College item with Renown (yields)
--   Purchases.claim_renown(player, ids) -> (ok, paid ids, total, why?)   orders, medals, laurels (Data/Claims; yields)
--   Purchases.has_unlock(player, key) / Purchases.unlock_mask(player)   what the player has unlocked
--   Purchases.starter_state(player) -> false | { state = "open", foundings = { key } }
--   Purchases.general_perks(player, cycles, day, skin) -> given?   what the Charter's paid cycles still owe (yields)
-- The Arsenal (Data/Arsenal): a product whose `grants` is "unlock:<key>" is not a credit — its receipt
-- unlocks that item for good (and pays the item's bonus Stars once). The same unlock bought twice (the
-- shop never offers it) pays Stars instead, DUPLICATE_STARS_PER_ROBUX for each Robux of its price.
-- The Founding Grant (Data/Starter): a product per founding, kind "starter:<key>". Its record `starter` = { started, ends,
-- used?, branch? } says it was taken (started and ends are the old clock's, kept in old saves and read by nothing). Like
-- every receipt here it is never refused: a paid receipt can't be left without its worth, so an item already held pays
-- its Renown price, and a second founding pays its Robux in Renown.
--
-- Spoils and the policy on paid random items (PolicyService.ArePaidRandomItemsRestricted). The prompt is only ever opened
-- for a client told crates_allowed (UI/Locker, the one place that prompts for Spoils, through Cosmetics.may_buy), but a
-- tampered client or a policy that changed can still bring a receipt. What that receipt does:
--   allowed (or the policy isn't known: they left, it hasn't answered)  a saved credit, as ever. Opening asks the policy
--     again, and a credit nobody may open yet stays saved.
--   known restricted  no credit and nothing random: what was paid comes back as Renown at DUPLICATE_STARS_PER_ROBUX, one of
--     Roblox's allowed treatments, and the receipt is granted. It is never answered "not processed" for policy reasons.
-- With nothing left to find, opening a credit pays Cosmetics.SPOILS_RENOWN and spends it: no paid outcome is empty.
-- The record: { credits = { kind = n }, receipts = { id }, owned = { [item] = true },
--   equipped = { skin = id?, flag = id? }, crates_bought = n, stars = n, stars_earned = n,
--   unlocks = { [key] = true }, paid = bool, starter = { started, ends, used? }?, gifts = { [item] = true },
--   claims = Data/Claims' state }.
-- The flag shop (Data/Shop; 2026-10-22): a product whose `grants` is "shopflag:<key>" adds that
-- flag (item "shop_<key>") and puts it on, whenever its receipt comes (the shop may have turned over
-- since the prompt opened). One already owned pays Stars instead, as a second Arsenal unlock does.
-- A set's bundle ("shopset:<id>", 2026-10-24) adds every flag of the set and wears its rarest new
-- one (unless one of the set is worn already); a flag owned before pays its share of the bundle's price
-- in Stars.
-- Exclusive cosmetics (Cosmetics.exclusive_skins, made for particular players): every read of a
-- record for a player (clean(v, user_id)) owns what Cosmetics.granted(user_id) lists, and the first
-- time (not yet in `gifts`) puts it on; nobody else's record can hold one.
local IS_ROBLOX = typeof(game) == "Instance"
local Products: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Products)
	else require("../shared/Data/Products")
local Cosmetics: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Cosmetics)
	else require("../shared/Data/Cosmetics")
local Arsenal: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Arsenal)
	else require("../shared/Data/Arsenal")
local Starter: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Starter)
	else require("../shared/Data/Starter")
local Shop: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Shop)
	else require("../shared/Data/Shop")
local Subscription: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Subscription)
	else require("../shared/Data/Subscription")
local Claims: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Claims)
	else require("../shared/Data/Claims")

local Purchases = {}

Purchases.STORE = "RofrontPurchases_v1"
--- Receipts remembered per player (a retried ProcessReceipt is always about a recent one).
Purchases.RECEIPTS_KEPT = 100
Purchases.MAX_CREDITS = 1000
Purchases.MAX_STARS = 1000000000
--- Renown for each Robux of something paid for twice or held already (Data/Shop.RENOWN_PER_ROBUX says why it is what it is).
Purchases.DUPLICATE_STARS_PER_ROBUX = Shop.RENOWN_PER_ROBUX
--- The muster's seventh day where Spoils aren't open to the player: Renown instead of the free dispatch.
Purchases.MUSTER_SPOILS_RENOWN = Claims.MUSTER_GIFT_RENOWN

type Record = {
	credits: { [string]: number },
	receipts: { string },
	owned: { [string]: boolean },
	equipped: { skin: string?, flag: string? },
	crates_bought: number,
	stars: number,
	stars_earned: number,
	unlocks: { [string]: boolean },
	--- the tutorial's Stars were paid (Data/Tutorial.STARS, once per player)
	tutorial_paid: boolean?,
	--- ever paid Robux (a record from before this field: it has receipts)
	paid: boolean,
	--- the Founding Grant, once taken (or the old timed offer's clock)
	starter: { started: number, ends: number, used: boolean?, branch: string? }?,
	--- exclusive items already given (and put on once): Cosmetics.granted
	gifts: { [string]: boolean },
	--- the Charter: the last UTC day paid (Purchases.general_perks)
	general_day: number?,
	--- what the second scoreboard has been paid (Data/Claims; a record from before it: empty)
	claims: { [string]: any },
}

--- Reading a player's record when they join: GetAsync attempts and the waits between them. Roblox
--- throttles DataStore reads now and then ("TooManyRequests ... API: GetAsync", 37 in a day on the
--- error report of 2026-10-05). The load used to give up after one attempt, and that player then
--- had none of their unlocks, Stars or cosmetics for the whole session.
Purchases.LOAD_ATTEMPTS = 5
Purchases.LOAD_BACKOFF = { 1, 3, 6, 10 }
--- After those the session goes on without the record, and the read is tried again every
--- LOAD_RETRY_S, LOAD_RETRIES more times, while the player stays.
Purchases.LOAD_RETRY_S = 20
Purchases.LOAD_RETRIES = 30

local deps: { [string]: any } = {}
local cache: { [any]: { [string]: number } } = {}
--- Players gone from this server (weak: they go once nothing else holds them).
local released: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
--- the player's items (the record's owned / equipped / crates_bought), as last read or written
local inv: { [any]: any } = {}
--- player -> the load that is still trying to read their record (a token: a newer load, a write
--- that brought the record, or leaving ends it)
local loading: { [any]: any } = {}

function Purchases.configure(d: { [string]: any })
	for k, v in d do
		deps[k] = v
	end
end

--- Tests: forget everyone.
function Purchases.reset()
	table.clear(cache)
	table.clear(inv)
	table.clear(loading)
	table.clear(released)
end

--- The credit kind a product grants (nil: not ours), and how many of it (the 3-crate pack: 3).
function Purchases.kind_of(product_id: number): (string?, number)
	for kind, p in Products do
		if p.id ~= 0 and p.id == product_id then
			-- (a first-only product keeps its own kind so grant can check it really is the first: release audit 2026-11-07)
			local g = if p.first_only then "first:" .. (p.grants or kind) else (p.grants or kind)
			return g, math.clamp(math.floor(tonumber(p.count) or 1), 1, 10)
		end
	end
	return nil, 0
end

local function key(user_id: number): string
	return "u" .. tostring(user_id)
end

--- The record's fields this build reads and writes itself; anything else is a newer build's, and is kept as it is.
local KNOWN_FIELDS: { [string]: boolean } = {
	credits = true, receipts = true, owned = true, equipped = true, crates_bought = true, stars = true,
	stars_earned = true, unlocks = true, paid = true, gifts = true, claims = true, tutorial_paid = true,
	general_day = true, starter = true,
}

local function clean(v: any, user_id: number?): Record
	local rec: Record = {
		credits = {},
		receipts = {},
		owned = {},
		equipped = {},
		crates_bought = 0,
		stars = 0,
		stars_earned = 0,
		unlocks = {},
		paid = false,
		gifts = {},
		claims = Claims.clean(nil),
	}
	if type(v) ~= "table" then
		v = {}
	end
	rec.claims = Claims.clean(v.claims)
	local function count(x: any): number
		local n = tonumber(x) or 0
		return if n ~= n then 0 else math.clamp(math.floor(n), 0, Purchases.MAX_STARS)
	end
	rec.stars = count(v.stars)
	rec.stars_earned = count(v.stars_earned)
	rec.tutorial_paid = if v.tutorial_paid == true then true else nil
	local gday = tonumber(v.general_day)
	rec.general_day = if gday ~= nil and gday == gday then math.floor(gday) else nil
	if type(v.unlocks) == "table" then
		for k, on in v.unlocks do
			if on == true and Arsenal.item(k) ~= nil then
				rec.unlocks[k] = true
			end
		end
	end
	if type(v.owned) == "table" then
		for id, on in v.owned do
			if on == true and Cosmetics.may_own(id, user_id) then
				rec.owned[id] = true
			end
		end
	end
	if type(v.gifts) == "table" then
		for id, on in v.gifts do
			if on == true and type(id) == "string" then
				rec.gifts[id] = true
			end
		end
	end
	if type(v.equipped) == "table" then
		for _, slot in { "skin", "flag" } do
			local id = v.equipped[slot]
			local it = Cosmetics.item(id)
			if it ~= nil and it.kind == slot and rec.owned[id] then
				rec.equipped[slot] = id
			end
		end
	end
	-- (made for this player: always owned; worn the first time, then their own choice)
	for _, id in Cosmetics.granted(user_id) do
		local it = Cosmetics.item(id)
		if it ~= nil then
			rec.owned[id] = true
			if not rec.gifts[id] then
				rec.gifts[id] = true
				rec.equipped[it.kind] = id
			end
		end
	end
	rec.crates_bought = math.max(0, math.floor(tonumber(v.crates_bought) or 0))
	if type(v.credits) == "table" then
		for k, n in v.credits do
			if type(k) == "string" and type(n) == "number" and n == n then
				rec.credits[k] = math.clamp(math.floor(n), 0, Purchases.MAX_CREDITS)
			end
		end
	end
	if type(v.receipts) == "table" then
		for _, r in v.receipts do
			if type(r) == "string" then
				table.insert(rec.receipts, r)
			end
		end
	end
	-- (a stored `paid` wins: Staging's "Replay as new player" sets it false with receipts kept)
	rec.paid = if type(v.paid) == "boolean" then v.paid else #rec.receipts > 0
	if type(v.starter) == "table" then
		local started, ends = tonumber(v.starter.started), tonumber(v.starter.ends)
		if started ~= nil and ends ~= nil and started == started and ends == ends then
			rec.starter = {
				started = started,
				ends = ends,
				used = if v.starter.used == true then true else nil,
				branch = if type(v.starter.branch) == "string" then v.starter.branch else nil,
			}
		end
	end
	-- What a newer build wrote and this one doesn't know is carried through untouched (release audit 2026-11-07: an
	-- older server still running after a publish rebuilt every save it wrote from what it knew, and erased the items,
	-- unlocks and fields a newer build had added, for good). Unknown ids stay owned; unknown fields stay as they were.
	if type(v.unlocks) == "table" then
		for k, on in v.unlocks do
			if on == true and type(k) == "string" and #k <= 64 and Arsenal.item(k) == nil then
				rec.unlocks[k] = true
			end
		end
	end
	if type(v.owned) == "table" then
		for id, on in v.owned do
			if on == true and type(id) == "string" and #id <= 64 and Cosmetics.item(id) == nil then
				rec.owned[id] = true
			end
		end
	end
	if type(v.equipped) == "table" then
		for _, slot in { "skin", "flag" } do
			local id = v.equipped[slot]
			if rec.equipped[slot] == nil and type(id) == "string" and Cosmetics.item(id) == nil and rec.owned[id] then
				rec.equipped[slot] = id
			end
		end
	end
	if type(v.claims) == "table" then
		for k, x in v.claims do
			if rec.claims[k] == nil then
				rec.claims[k] = x
			end
		end
	end
	for k, x in v do
		if type(k) == "string" and not KNOWN_FIELDS[k] then
			rec[k] = x
		end
	end
	return rec
end

local function log(text: string)
	if deps.log then
		deps.log("[Purchases] " .. text)
	end
end

--- Renown in ("Source") or out ("Sink") for the Economy dashboard (deps.economy = Analytics.economy), after the write
--- that moved it; `balance` is the wallet that write stored. Nothing when no one is there or nothing moved.
local function economy(
	player: any,
	flow: string,
	amount: number,
	balance: number,
	transaction: string,
	sku: string?,
	f: { string }?
)
	if player == nil or amount <= 0 or deps.economy == nil then
		return
	end
	pcall(deps.economy, player, flow, amount, balance, transaction, sku, f)
end

--- What a claim id is, for the Economy dashboard: (its transaction, its sku). Data/Claims writes the ids.
function Purchases.claim_kind(id: string): (string, string)
	local p = string.sub(id, 1, 2)
	if p == "d:" then
		return "TimedReward", "Muster"
	elseif p == "o:" then
		return "Gameplay", "Order"
	elseif p == "m:" then
		return "Gameplay", "Medal"
	elseif p == "l:" then
		return "Gameplay", "Laurel"
	elseif p == "s:" then
		return "Gameplay", "Season"
	end
	return "Gameplay", "Claim"
end

local function player_by_id(user_id: number): any
	local ps = deps.players
	if ps == nil then
		return nil
	end
	local ok, p = pcall(function()
		return ps:GetPlayerByUserId(user_id)
	end)
	return if ok then p else nil
end

local function remember(player: any, rec: Record)
	-- (a write that lands after the player left — a war's pay — must not bring them back into memory: release audit
	-- 2026-11-07 found long-lived hubs slowly filling with players who had gone)
	if released[player] then
		return
	end
	loading[player] = nil -- (the record is here: a load still retrying has nothing left to do)
	cache[player] = rec.credits
	inv[player] = {
		owned = rec.owned,
		equipped = rec.equipped,
		crates_bought = rec.crates_bought,
		stars = rec.stars,
		stars_earned = rec.stars_earned,
		unlocks = rec.unlocks,
		paid = rec.paid,
		starter = rec.starter,
		claims = rec.claims,
	}
end

local function now_s(): number
	return if type(deps.now) == "function" then deps.now() else os.time()
end

--- The foundings on sale here to a ruler (Studio: their prompts are tests) with these unlocks: their keys.
local function foundings_open(r: any): { string }
	local out = {}
	for _, f in Starter.FOUNDINGS do
		local p = Products[f.product]
		if p ~= nil and (p.id ~= 0 or deps.studio == true) and Starter.useful(f, r.unlocks) then
			table.insert(out, f.key)
		end
	end
	return out
end

--- Unlocks Arsenal item `it` on `rec` (a Robux receipt, or Stars already taken): its bonus Stars come
--- with it once. Already unlocked: Stars for the price instead.
local function unlock_on(rec: Record, it: any, robux: number?)
	if rec.unlocks[it.key] then
		local back = math.floor((robux or 0) * Purchases.DUPLICATE_STARS_PER_ROBUX)
		rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
		return
	end
	rec.unlocks[it.key] = true
	rec.stars = math.min(rec.stars + (it.bonus or 0), Purchases.MAX_STARS)
end

local function notify(player: any)
	if player ~= nil and deps.notify then
		pcall(deps.notify, player, table.clone(cache[player] or {}))
	end
	if player ~= nil and deps.inventory then
		pcall(deps.inventory, player, Purchases.inventory(player))
	end
end

--- What is worn, as far as this build knows the items.
local function known_worn(eq: any): any
	local out = {}
	for slot, id in eq do
		if Cosmetics.item(id) ~= nil then
			out[slot] = id
		end
	end
	return out
end

--- The player's items for the client: owned ids (list), equipped, crates bought.
function Purchases.inventory(player: any): any
	local i = inv[player]
	local owned = {}
	if i ~= nil then
		for id in i.owned do
			-- (only what this build knows: a newer build's items stay saved, unseen here)
			if Cosmetics.item(id) ~= nil then
				table.insert(owned, id)
			end
		end
		table.sort(owned)
	end
	local unlocks = {}
	if i ~= nil then
		for k in i.unlocks do
			if Arsenal.item(k) ~= nil then
				table.insert(unlocks, k)
			end
		end
		table.sort(unlocks)
	end
	return {
		owned = owned,
		equipped = if i ~= nil then known_worn(i.equipped) else {},
		crates_bought = if i ~= nil then i.crates_bought else 0,
		stars = if i ~= nil then i.stars else 0,
		-- (false until the record has been read: an inventory sent before it is no record of 0 Renown)
		loaded = i ~= nil,
		unlocks = unlocks,
		starter = Purchases.starter_state(player),
		claims = if i ~= nil then i.claims else nil,
	}
end

--- The Founding Grant for this player: false (taken, nothing left in it for them, none on sale here, or they have yet to
--- play: a ruler who has fought knows what they are choosing), or { state = "open", foundings = the keys they may choose }.
function Purchases.starter_state(player: any): any
	local i = inv[player]
	if i == nil or (i.starter ~= nil and i.starter.used) or (i.stars_earned or 0) <= 0 then
		return false
	end
	local open = foundings_open(i)
	return if #open > 0 then { state = "open", foundings = open } else false
end

--- True when the player has Arsenal item `key` (as last read or written).
function Purchases.has_unlock(player: any, key: string): boolean
	local i = inv[player]
	return i ~= nil and i.unlocks[key] == true and Arsenal.item(key) ~= nil -- (a newer build's unlock stays saved, unused here)
end

--- The player's Arsenal as the Sim's bit mask (Defs.UNLOCK; Sim.set_unlocks).
function Purchases.unlock_mask(player: any): number
	local i = inv[player]
	return if i ~= nil then Arsenal.mask(i.unlocks) else 0
end

function Purchases.stars(player: any): number
	local i = inv[player]
	return if i ~= nil then i.stars else 0
end

--- What the player shows in a match: { skin = id?, flag = id? } (nil when nothing is equipped).
function Purchases.equipped(player: any): any
	local i = inv[player]
	local worn = if i ~= nil then known_worn(i.equipped) else {}
	if worn.skin == nil and worn.flag == nil then
		return nil
	end
	return worn
end

--- Roblox's ProcessReceipt: store the credit, then say granted (never before it is stored).
function Purchases.process_receipt(info: any): string
	local user_id = tonumber(info and info.PlayerId)
	local product = tonumber(info and info.ProductId)
	local receipt = if info and type(info.PurchaseId) == "string" then info.PurchaseId else nil
	local kind, n = nil, 1
	if product then
		kind, n = Purchases.kind_of(product)
	end
	if user_id == nil or kind == nil or receipt == nil then
		log("unknown receipt for product " .. tostring(product))
		return "not_processed"
	end
	return Purchases.grant(user_id, kind, receipt, n, tonumber(info.CurrencySpent))
end

--- Store `n` (default 1) `kind` credits for `user_id` under `receipt` (once per receipt). "granted" once
--- stored. `spent`: the Robux the receipt says were paid (Managed Pricing: not always the set price),
--- passed on to deps.bought.
function Purchases.grant(user_id: number, kind: string, receipt: string, n: number?, spent: number?): string
	local count = math.clamp(math.floor(n or 1), 1, 10)
	local stored: Record? = nil
	--- the Renown this receipt gave (set on each run of the write: a retried receipt gives none)
	local gained = 0
	--- A first-only product ("first:crate"): what it grants, when it really is the buyer's first (checked in the record).
	local first_of = string.match(kind, "^first:(.+)$")
	local buyer = player_by_id(user_id)
	local restricted = kind == "crate"
		and buyer ~= nil
		and Purchases.crates_policy ~= nil
		and Purchases.crates_policy(buyer) == false
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(user_id), function(old: any): any
			local rec = clean(old, user_id)
			gained = 0
			local before = rec.stars
			if table.find(rec.receipts, receipt) then
				stored = rec -- granted before (a retry): nothing to add
				return nil
			end
			if first_of ~= nil then
				if (rec.crates_bought or 0) > 0 then
					-- (the first's low price, paid again by a client that offered it twice: the Robux back as Renown, never a
					-- second cheap dispatch; the purchase is never lost)
					local robux = if spent ~= nil and spent > 0 then spent else 0
					rec.stars = math.min(rec.stars + math.floor(robux * Purchases.DUPLICATE_STARS_PER_ROBUX), Purchases.MAX_STARS)
					table.insert(rec.receipts, receipt)
					while #rec.receipts > Purchases.RECEIPTS_KEPT do
						table.remove(rec.receipts, 1)
					end
					rec.paid = true
					stored = rec
					gained = rec.stars - before
					return rec
				end
				kind = first_of
				restricted = kind == "crate"
					and buyer ~= nil
					and Purchases.crates_policy ~= nil
					and Purchases.crates_policy(buyer) == false
			end
			local unlock_key = string.match(kind, "^unlock:(.+)$")
			local it = if unlock_key ~= nil then Arsenal.item(unlock_key) else nil
			local shop_key = string.match(kind, "^shopflag:(.+)$")
			local set_id = string.match(kind, "^shopset:(.+)$")
			local founding_key = string.match(kind, "^starter:(.+)$")
			if set_id ~= nil then
				local keys = Shop.set_keys(set_id)
				local total = Shop.set_total(set_id)
				local p = Products["shopset_" .. set_id]
				local paid = if p ~= nil then p.robux else 0
				local wear: string? = nil
				for _, k in keys do
					local id = Shop.item_id(k)
					if rec.owned[id] then
						local share = if total > 0 then paid * Shop.price(Shop.flag(k)) / total else 0
						rec.stars = math.min(rec.stars + math.floor(share * Purchases.DUPLICATE_STARS_PER_ROBUX), Purchases.MAX_STARS)
					else
						rec.owned[id] = true
						wear = wear or id -- (the keys come rarest first)
					end
				end
				if #keys == 0 then
					rec.stars = math.min(rec.stars + math.floor(paid * Purchases.DUPLICATE_STARS_PER_ROBUX), Purchases.MAX_STARS)
				end
				local worn = Shop.key_of(rec.equipped.flag)
				local worn_set = if worn ~= nil then (Shop.flag(worn) :: any).set else nil
				if wear ~= nil and worn_set ~= set_id then
					rec.equipped.flag = wear
				end
			elseif shop_key ~= nil then
				local id = Shop.item_id(shop_key)
				if Shop.flag(shop_key) == nil or rec.owned[id] then
					-- (owned already, or a flag this build doesn't know: Stars for the price)
					local p = Products["shop_" .. shop_key]
					local back = math.floor((if p ~= nil then p.robux else 0) * Purchases.DUPLICATE_STARS_PER_ROBUX)
					rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
				else
					rec.owned[id] = true
					rec.equipped.flag = id -- (chosen and paid for: worn at once)
				end
			elseif founding_key ~= nil then
				local f = Starter.founding(founding_key)
				local p = if f ~= nil then Products[f.product] else nil
				local used = rec.starter ~= nil and rec.starter.used == true
				if f == nil or used then
					-- (a second founding, or one this build doesn't know: its Robux in Renown)
					local back = math.floor((if p ~= nil then p.robux else 0) * Purchases.DUPLICATE_STARS_PER_ROBUX)
					rec.stars = math.min(rec.stars + back, Purchases.MAX_STARS)
				else
					for _, k in f.items do
						local item = Arsenal.item(k)
						if item ~= nil and rec.unlocks[k] then
							rec.stars = math.min(rec.stars + (item.stars or 0), Purchases.MAX_STARS)
						elseif item ~= nil then
							unlock_on(rec, item, 0)
						end
					end
					rec.stars = math.min(rec.stars + f.renown, Purchases.MAX_STARS)
					local t = now_s()
					rec.starter = { started = t, ends = t, used = true, branch = f.key }
				end
			elseif it ~= nil then
				local p = Products[it.product]
				unlock_on(rec, it, if p ~= nil then p.robux else 0)
			elseif kind == "crate" and restricted then
				-- (nothing random for a player the policy bars: see the top of this file)
				local robux = if spent ~= nil and spent > 0 then spent else count * Products.crate.robux
				rec.stars = math.min(rec.stars + math.floor(robux * Purchases.DUPLICATE_STARS_PER_ROBUX), Purchases.MAX_STARS)
			else
				rec.credits[kind] = math.min((rec.credits[kind] or 0) + count, Purchases.MAX_CREDITS)
				if kind == "crate" then
					rec.crates_bought += count
				end
			end
			table.insert(rec.receipts, receipt)
			while #rec.receipts > Purchases.RECEIPTS_KEPT do
				table.remove(rec.receipts, 1)
			end
			rec.paid = true
			stored = rec
			gained = rec.stars - before
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("could not store receipt " .. receipt .. ": " .. tostring(err))
		return "not_processed"
	end
	local player = player_by_id(user_id)
	if player ~= nil then
		remember(player, stored :: Record)
		notify(player)
		if deps.bought then
			-- (a first-only product is logged as what it grants)
			pcall(deps.bought, player, string.gsub(kind, "^first:", "") :: string, count, spent)
		end
		local unlocked = if string.match(kind, "^starter:") then "" else string.match(kind, "^unlock:(.+)$")
		if unlocked ~= nil and deps.unlocked then
			pcall(deps.unlocked, player, unlocked)
		end
		economy(player, "Source", gained, (stored :: Record).stars, "IAP", (string.gsub(kind, "^first:", "")))
	end
	log(string.format("granted %s%s to %d (%s)", kind, if count > 1 then " x" .. count else "", user_id, receipt))
	return "granted"
end

--- Yields: LOAD_ATTEMPTS reads with LOAD_BACKOFF between them, then, with the session already going
--- on an empty record, more every LOAD_RETRY_S (deps.wait; without one, a single attempt).
function Purchases.load(player: any)
	released[player] = nil
	local token = {}
	loading[player] = token
	local wait = deps.wait
	local tries = 0
	while true do
		tries += 1
		local ok, v = pcall(function()
			return deps.datastore:GetAsync(key(player.UserId))
		end)
		if loading[player] ~= token then
			return -- (they left, a write brought the record, or another load began)
		end
		if ok then
			remember(player, clean(v, player.UserId))
			notify(player)
			if tries > Purchases.LOAD_ATTEMPTS and deps.unlocked then
				-- (it came late: the match they are in learns what they have unlocked)
				pcall(deps.unlocked, player, "")
			end
			return
		end
		local last = not wait or tries >= Purchases.LOAD_ATTEMPTS + Purchases.LOAD_RETRIES
		if tries == Purchases.LOAD_ATTEMPTS or (last and tries < Purchases.LOAD_ATTEMPTS) then
			cache[player] = cache[player] or {}
			log(
				"load failed for "
					.. tostring(player.UserId)
					.. ": "
					.. tostring(v)
					.. (if last then "" else " (trying again while they stay)")
			)
			notify(player)
		end
		if last then
			loading[player] = nil
			return
		end
		wait(if tries < Purchases.LOAD_ATTEMPTS then Purchases.LOAD_BACKOFF[tries] or 10 else Purchases.LOAD_RETRY_S)
	end
end

function Purchases.credits(player: any): { [string]: number }
	return table.clone(cache[player] or {})
end

--- Spend one `kind` credit (atomic on the stored record). Yields.
function Purchases.use(player: any, kind: string): (boolean, string?)
	if Products[kind] == nil then
		return false, "unknown product"
	end
	local spent = false
	local left: { [string]: number }? = nil
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			spent = false
			local rec = clean(old, player.UserId)
			left = rec.credits
			remember(player, rec)
			if (rec.credits[kind] or 0) <= 0 then
				return nil
			end
			rec.credits[kind] -= 1
			spent = true
			left = rec.credits
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if left ~= nil then
		cache[player] = left
	end
	notify(player)
	if not spent then
		return false, "no credit"
	end
	return true, nil
end

function Purchases.release(player: any)
	loading[player] = nil
	cache[player] = nil
	inv[player] = nil
	released[player] = true
end

--- PolicyService's answer (pcall's ok, GetPolicyInfoForPlayerAsync's table) as what this game offers: `crates` true or false
--- when it answered, nil when it didn't (nothing is offered on nil, and a receipt is kept as a credit); `charter` true only
--- on a plain yes to IsEligibleToPurchaseSubscription.
function Purchases.read_policy(ok: boolean, info: any): { crates: boolean?, charter: boolean }
	if not ok or type(info) ~= "table" then
		return { crates = nil, charter = false }
	end
	local r = info.ArePaidRandomItemsRestricted
	return {
		crates = if type(r) == "boolean" then not r else nil,
		charter = info.IsEligibleToPurchaseSubscription == true,
	}
end

--- Open one dispatch of Spoils: spend a credit and add an item the player doesn't own (Cosmetics.roll, the published
--- odds), in one write; the new item is equipped when its slot is empty. With nothing left to find, the credit pays
--- Cosmetics.SPOILS_RENOWN instead. Yields.
--- (true, item_id), (true, "renown", amount), or (false, "not allowed" | "no crate" | "store unavailable: ...").
function Purchases.open_crate(player: any): (boolean, string?, number?)
	-- Where Spoils are restricted nothing random opens, whatever the client sends: a dispatch held there (bought before,
	-- or a gift) is taken as Renown instead, at its Robux worth, so it is never stuck (release audit 2026-11-07).
	-- (only on the policy's own "no": unknown yet, as just after joining, waits and the credit stays as it is)
	local barred = false
	if Purchases.crates_allowed ~= nil and not Purchases.crates_allowed(player) then
		if Purchases.crates_policy == nil or Purchases.crates_policy(player) ~= false then
			return false, "not allowed"
		end
		barred = true
	end
	local rng = deps.rng or Random.new()
	local got: string? = nil
	local renown: number? = nil
	local stored: Record? = nil
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			got, renown = nil, nil
			local rec = clean(old, player.UserId)
			stored = rec
			if (rec.credits.crate or 0) <= 0 then
				return nil
			end
			rec.credits.crate -= 1
			if barred then
				renown = math.floor(Products.crate.robux * Purchases.DUPLICATE_STARS_PER_ROBUX)
				rec.stars = math.min(rec.stars + renown, Purchases.MAX_STARS)
				got = "renown"
				return rec
			end
			local id = Cosmetics.roll(rec.owned, rng:NextNumber(), rng:NextNumber())
			if id == nil then
				renown = Cosmetics.SPOILS_RENOWN
				rec.stars = math.min(rec.stars + Cosmetics.SPOILS_RENOWN, Purchases.MAX_STARS)
				got = "renown"
				return rec
			end
			rec.owned[id] = true
			local it = Cosmetics.item(id)
			if it ~= nil and rec.equipped[it.kind] == nil then
				rec.equipped[it.kind] = id
			end
			got = id
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if got == nil then
		return false, "no crate"
	end
	if got == "renown" and renown ~= nil and stored ~= nil then
		economy(player, "Source", renown, (stored :: Record).stars, "IAP", "Spoils", { if barred then "Restricted" else "Duplicate" })
	end
	return true, got, renown
end

--- Equip an owned item in its slot ("skin" / "flag"), or clear the slot (id false). Yields.
function Purchases.equip(player: any, slot: string, id: any): (boolean, string?)
	if slot ~= "skin" and slot ~= "flag" then
		return false, "bad slot"
	end
	if id ~= false then
		local it = Cosmetics.item(id)
		if it == nil or it.kind ~= slot then
			return false, "unknown item"
		end
	end
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if id ~= false and not rec.owned[id] then
				return nil
			end
			rec.equipped[slot] = if id == false then nil else id
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	return done, if done then nil else "not owned"
end

--- Pays `amount` Stars (a match's payout, Data/Stars). Yields. (ok, the new balance).
--- The Stars for finishing the tutorial (Data/Tutorial), once per player. True when they were paid now.
function Purchases.tutorial_bonus(player: any, amount: number): boolean
	local add = math.floor(tonumber(amount) or 0)
	if add ~= add or add <= 0 then
		return false
	end
	local stored: Record? = nil
	local paid = false
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.tutorial_paid then
				paid = false
				return nil
			end
			paid = true
			rec.tutorial_paid = true
			rec.stars = math.min(rec.stars + add, Purchases.MAX_STARS)
			rec.stars_earned = math.min(rec.stars_earned + add, Purchases.MAX_STARS)
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("could not pay the tutorial's Stars to " .. tostring(player.UserId) .. ": " .. tostring(err))
		return false
	end
	remember(player, stored :: Record)
	if paid then
		notify(player)
		economy(player, "Source", add, (stored :: Record).stars, "Onboarding", "Tutorial")
	end
	return paid
end

--- The Charter (Data/Subscription; server/General calls it with Roblox's paid cycles): every day those cycles still owe, up
--- to `day`, at DAILY_RENOWN, and the Charter's Pattern `skin` once any cycle has been paid (kept for good; put on when no
--- Pattern is worn). One write, and `general_day` moves with the payment, so a retry can't pay a day twice and a failure
--- loses none. Returns what it gave now ({ days?, stars?, skin? }; {} when nothing was owed), or nil when the store failed.
function Purchases.general_perks(player: any, cycles: { any }, day: number, skin: string?): any
	local it = if skin ~= nil then Cosmetics.item(skin) else nil
	local stored: Record? = nil
	local given: any = {}
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			local rec = clean(old, player.UserId)
			stored = rec
			given = {}
			local changed = false
			local n, last = Subscription.days_owed(cycles, rec.general_day, day)
			if n > 0 then
				local add = n * Subscription.DAILY_RENOWN
				rec.general_day = last
				rec.stars = math.min(rec.stars + add, Purchases.MAX_STARS)
				rec.stars_earned = math.min(rec.stars_earned + add, Purchases.MAX_STARS)
				given.days = n
				given.stars = add
				changed = true
			end
			if #cycles > 0 and it ~= nil and it.general and not rec.owned[it.id] then
				rec.owned[it.id] = true
				if rec.equipped[it.kind] == nil then
					rec.equipped[it.kind] = it.id
				end
				given.skin = it.id
				changed = true
			end
			return if changed then rec else nil
		end)
	end)
	if not ok or stored == nil then
		log("could not pay " .. tostring(player.UserId) .. " their Charter days: " .. tostring(err))
		return nil
	end
	remember(player, stored :: Record)
	if next(given) ~= nil then
		notify(player)
	end
	if given.stars ~= nil then
		economy(player, "Source", given.stars, (stored :: Record).stars, "TimedReward", "Charter Daily", { tostring(given.days or 1) .. " days" })
	end
	return given
end

--- Rofront Staging's "Replay as new player": the tutorial's Stars can be earned again, the first
--- dispatch's price is on offer again, and so is the Founding Grant (as one who never paid, and without the foundings'
--- items, which a new player doesn't have: the only things taken; Renown, cosmetics and other unlocks stay). `keep_owned` (a game admin on production,
--- 2026-10-27): nothing is taken, and one who paid is still one who paid.
function Purchases.reset_new_player(player: any, keep_owned: boolean?): boolean
	local stored: Record? = nil
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			local rec = clean(old, player.UserId)
			rec.tutorial_paid = nil
			rec.crates_bought = 0
			rec.starter = nil
			if not keep_owned then
				rec.paid = false
				for _, k in Starter.all_items() do
					rec.unlocks[k] = nil
				end
			end
			stored = rec
			return rec
		end)
	end)
	if not ok or stored == nil then
		log("could not reset " .. tostring(player.UserId) .. ": " .. tostring(err))
		return false
	end
	remember(player, stored :: Record)
	notify(player)
	return true
end

--- `minutes`: how long the match that pays it really lasted on the server's clock (Data/Claims lets that much through).
--- Tries at a war's pay before it gives up (a second and third after 1.5 s and 3 s).
Purchases.PAY_ATTEMPTS = 3
Purchases._in_flight = 0

--- Writes of a war's pay still going (a closing server waits for them: ServerMain's BindToClose).
function Purchases.busy(): number
	return Purchases._in_flight
end

function Purchases.add_stars(player: any, amount: number, minutes: number?): (boolean, number)
	local add = math.floor(tonumber(amount) or 0)
	if add ~= add or add <= 0 then
		return false, Purchases.stars(player)
	end
	local stored: Record? = nil
	local ok, err = false, nil
	-- (a war's pay: a store hiccup is retried, and a server closing waits for it: Purchases.busy; release audit 2026-11-07)
	Purchases._in_flight += 1
	for attempt = 1, Purchases.PAY_ATTEMPTS do
		ok, err = pcall(function()
			deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
				local rec = clean(old, player.UserId)
				rec.stars = math.min(rec.stars + add, Purchases.MAX_STARS)
				rec.stars_earned = math.min(rec.stars_earned + add, Purchases.MAX_STARS)
				Claims.add_minutes(rec.claims, minutes, now_s() // 86400)
				stored = rec
				return rec
			end)
		end)
		if ok and stored ~= nil then
			break
		end
		if attempt < Purchases.PAY_ATTEMPTS and deps.wait then
			deps.wait(attempt * 1.5)
		end
	end
	Purchases._in_flight -= 1
	if not ok or stored == nil then
		log("could not pay " .. tostring(add) .. " Stars to " .. tostring(player.UserId) .. ": " .. tostring(err))
		return false, Purchases.stars(player)
	end
	remember(player, stored :: Record)
	notify(player)
	return true, (stored :: Record).stars
end

--- Orders, medals, laurels and season levels the client says are earned, for Renown (Data/Claims says what is checked,
--- and what a tampered client can still get). One write for the whole message, so a claim is paid and marked together:
--- a retry can't pay it twice. Yields. Returns (ok, the ids paid, the Renown, why the first one refused was refused).
function Purchases.claim_renown(player: any, ids: any): (boolean, { string }, number, string?)
	if type(ids) ~= "table" or #ids > Claims.MAX_IDS then
		return false, {}, 0, "bad claim"
	end
	local paid: { string } = {}
	local total = 0
	local why: string? = nil
	local stored: Record? = nil
	local gift = false
	--- { id, Renown } of each id paid (the Economy dashboard's rows)
	local amounts: { { any } } = {}
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			paid, total, why, gift, amounts = {}, 0, nil, false, {}
			local rec = clean(old, player.UserId)
			stored = rec
			local day = now_s() // 86400
			for i = 1, #ids do
				local amount, no = Claims.apply(rec.claims, ids[i], day)
				if amount ~= nil then
					table.insert(paid, ids[i])
					total += amount
					local row = { ids[i], amount }
					table.insert(amounts, row)
					if ids[i] == Claims.muster_id(#Claims.MUSTER) then
						-- the muster's seventh day: a free Spoils where they're allowed (free, so no purchase rules; it
						-- doesn't count as one bought), else its worth in Renown
						if Purchases.crates_policy ~= nil and Purchases.crates_policy(player) == true then
							rec.credits.crate = math.min((rec.credits.crate or 0) + 1, Purchases.MAX_CREDITS)
							gift = true
						else
							total += Purchases.MUSTER_SPOILS_RENOWN
							row[2] += Purchases.MUSTER_SPOILS_RENOWN
						end
					end
				elseif why == nil then
					why = no
				end
			end
			if total <= 0 and not gift then
				return nil
			end
			rec.stars = math.min(rec.stars + total, Purchases.MAX_STARS)
			rec.stars_earned = math.min(rec.stars_earned + total, Purchases.MAX_STARS)
			return rec
		end)
	end)
	if not ok then
		log("could not pay a claim to " .. tostring(player.UserId) .. ": " .. tostring(err))
		return false, {}, 0, "store unavailable"
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	if total > 0 then
		notify(player)
		log(string.format("%d claimed %d Renown (%d ids)", player.UserId, total, #paid))
		if stored ~= nil then
			local running = (stored :: Record).stars - total
			for _, row in amounts do
				running += row[2]
				local transaction, sku = Purchases.claim_kind(row[1])
				economy(player, "Source", row[2], running, transaction, sku)
			end
		end
	end
	return true, paid, total, why
end

--- Unlock War College item `key` with Renown: one write takes its price and unlocks it. Its prerequisites must be yours
--- (Arsenal `needs`; only here: an item already owned stays owned, and a Robux receipt always grants). Yields.
--- (ok) or (false, "unknown item" | "robux only" | "owned" | "locked" | "not enough" | "store unavailable: ...").
--- Buy cosmetic `item_id` outright with Renown (a country's Standard: Cosmetics.renown_price), and wear it. One write takes
--- the price and adds the item. (ok, why?): "unknown item", "not for renown", "owned", "not enough", "store unavailable".
function Purchases.buy_cosmetic(player: any, item_id: any): (boolean, string?)
	local it = Cosmetics.item(item_id)
	if it == nil then
		return false, "unknown item"
	end
	local price = Cosmetics.renown_price(it)
	if price == nil then
		return false, "not for renown"
	end
	local why = "store unavailable"
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.owned[it.id] then
				why = "owned"
				return nil
			end
			if rec.stars < price then
				why = "not enough"
				return nil
			end
			rec.stars -= price
			rec.owned[it.id] = true
			rec.equipped[it.kind] = it.id -- (chosen and paid for: worn at once, as a bought Standard is)
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if not done then
		return false, why
	end
	economy(player, "Sink", price, (stored :: Record).stars, "Shop", it.id, { "Standard" })
	log(string.format("%d bought %s for %d Renown", player.UserId, it.id, price))
	return true, nil
end

function Purchases.buy_unlock(player: any, item_key: any): (boolean, string?)
	local it = Arsenal.item(item_key)
	if it == nil then
		return false, "unknown item"
	end
	if it.stars == nil then
		return false, "robux only"
	end
	local why = "store unavailable"
	local done = false
	local stored: Record? = nil
	local ok, err = pcall(function()
		deps.datastore:UpdateAsync(key(player.UserId), function(old: any): any
			done = false
			local rec = clean(old, player.UserId)
			stored = rec
			if rec.unlocks[it.key] then
				why = "owned"
				return nil
			end
			if #Arsenal.missing(it, rec.unlocks) > 0 then
				why = "locked"
				return nil
			end
			if rec.stars < it.stars then
				why = "not enough"
				return nil
			end
			rec.stars -= it.stars
			unlock_on(rec, it, 0)
			done = true
			return rec
		end)
	end)
	if not ok then
		return false, "store unavailable: " .. tostring(err)
	end
	if stored ~= nil then
		remember(player, stored :: Record)
	end
	notify(player)
	if not done then
		return false, why
	end
	if deps.unlocked then
		pcall(deps.unlocked, player, it.key)
	end
	-- (an item with a `bonus` gives Renown back as it unlocks: none has one today, Data/Arsenal)
	economy(player, "Sink", it.stars, (stored :: Record).stars - (it.bonus or 0), "Shop", it.key, { "War College" })
	if (it.bonus or 0) > 0 then
		economy(player, "Source", it.bonus, (stored :: Record).stars, "Gameplay", it.key, { "Unlock Bonus" })
	end
	log(string.format("%d unlocked %s for %d Stars", player.UserId, it.key, it.stars))
	return true, nil
end

return Purchases
